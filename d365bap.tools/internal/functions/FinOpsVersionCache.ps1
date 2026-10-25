<#
    .SYNOPSIS
        Returns the cache file path.
        
    .DESCRIPTION
        Builds the user-scoped path of the FinOps version catalog cache file.
        
    .EXAMPLE
        PS C:\> Get-FinOpsVersionCachePath
        
        Shows where the catalog cache lives.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>

function Get-FinOpsVersionCachePath {
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }

	Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'
}

function Get-FinOpsVersionCacheStamp {
	<#
        .SYNOPSIS
            Returns the current tenant and account.
        
        .DESCRIPTION
            Reads the active login for a best-effort cache stamp.
        
        .EXAMPLE
            PS C:\> Get-FinOpsVersionCacheStamp
        
            Shows the stamp used to validate cached data.
        
        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param ()

	$tenantId = ''
	$accountId = ''

	try {
		$provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

		if ("$provider" -eq 'AzCli') {
			$raw = & az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null

			if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$raw")) {
				$accountObj = "$raw" | ConvertFrom-Json -ErrorAction Stop
				$accountId = "$($accountObj.user)"
				$tenantId = "$($accountObj.tenant)"
			}
		}
		else {
			$azContext = Get-AzContext -ErrorAction SilentlyContinue

			if ($null -ne $azContext) {
				$accountId = "$($azContext.Account.Id)"
				$tenantId = "$($azContext.Tenant.Id)"
			}
		}
	}
	catch {
		Write-PSFMessage -Level Verbose -Message "FinOps version cache stamp unavailable: $($_.Exception.Message)"
	}

	return @{
		TenantId  = "$tenantId"
		AccountId = "$accountId"
	}
}

function Get-FinOpsVersionCache {
	<#
        .SYNOPSIS
            Reads the cached version catalog.
        
        .DESCRIPTION
            Returns the cached catalog or null on a miss.
        
        .PARAMETER MaxAgeHours
            Maximum cache age in hours.
            
            Default: 24
        
        .EXAMPLE
            PS C:\> Get-FinOpsVersionCache
        
            Returns the cached catalog or null.
        
        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	param (
		[int] $MaxAgeHours = 24
	)

	$path = Get-FinOpsVersionCachePath

	if (-not (Test-Path -LiteralPath $path)) { return $null }

	try {
		$state = Get-Content -LiteralPath $path -Raw -Encoding utf8 -ErrorAction Stop | `
			ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		Write-PSFMessage -Level Verbose -Message "Ignoring unreadable FinOps version cache at $path : $($_.Exception.Message)"

		return $null
	}

	if ($null -eq $state.refreshedUtc -or $null -eq $state.versions) { return $null }

	try {
		$refreshed = [datetime]$state.refreshedUtc
		$ageHours = ([datetime]::UtcNow - $refreshed.ToUniversalTime()).TotalHours
	}
	catch {
		return $null
	}

	if ($ageHours -gt $MaxAgeHours) { return $null }

	$stamp = Get-FinOpsVersionCacheStamp

	if (-not [string]::IsNullOrWhiteSpace("$($state.tenantId)") -and -not [string]::IsNullOrWhiteSpace("$($stamp.TenantId)") -and "$($state.tenantId)" -ne "$($stamp.TenantId)") {
		return $null
	}

	if (-not [string]::IsNullOrWhiteSpace("$($state.accountId)") -and -not [string]::IsNullOrWhiteSpace("$($stamp.AccountId)") -and "$($state.accountId)" -ne "$($stamp.AccountId)") {
		return $null
	}

	return $state
}

function Write-FinOpsVersionCache {
	<#
        .SYNOPSIS
            Merges data into the version cache.
        
        .DESCRIPTION
            Never throws. Foreign tenant entries are dropped, not carried over.
        
        .PARAMETER Versions
            Catalog rows to merge into the cache.
        
        .PARAMETER Builds
            Build lists per track to merge.
        
        .PARAMETER Platforms
            Platform versions per build to merge.
        
        .EXAMPLE
            PS C:\> Write-FinOpsVersionCache -Versions $catalog
        
            Merges fresh catalog rows into the cache.
        
        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	param (
		[object[]] $Versions,

		[hashtable] $Builds,

		[hashtable] $Platforms
	)

	try {
		$path = Get-FinOpsVersionCachePath
		$current = $null

		if (Test-Path -LiteralPath $path) {
			try {
				$current = Get-Content -LiteralPath $path -Raw -Encoding utf8 -ErrorAction Stop | `
					ConvertFrom-Json -ErrorAction Stop
			}
			catch {
				Write-PSFMessage -Level Verbose -Message "Ignoring unreadable FinOps version cache at $path : $($_.Exception.Message)"
				$current = $null
			}
		}

		$stamp = Get-FinOpsVersionCacheStamp
		$tenantChanged = $false

		if ($null -ne $current -and -not [string]::IsNullOrWhiteSpace("$($current.tenantId)") -and -not [string]::IsNullOrWhiteSpace("$($stamp.TenantId)") -and "$($current.tenantId)" -ne "$($stamp.TenantId)") {
			$tenantChanged = $true
		}

		if ($null -ne $current -and -not [string]::IsNullOrWhiteSpace("$($current.accountId)") -and -not [string]::IsNullOrWhiteSpace("$($stamp.AccountId)") -and "$($current.accountId)" -ne "$($stamp.AccountId)") {
			$tenantChanged = $true
		}

		$mergedBuilds = @{}

		if (-not $tenantChanged -and $null -ne $current -and $null -ne $current.builds) {
			foreach ($prop in $current.builds.PSObject.Properties) {
				$mergedBuilds[$prop.Name] = @($prop.Value)
			}
		}

		if ($null -ne $Builds) {
			foreach ($key in $Builds.Keys) {
				$mergedBuilds["$key"] = @($Builds[$key])
			}
		}

		$mergedPlatforms = @{}

		if (-not $tenantChanged -and $null -ne $current -and $null -ne $current.platforms) {
			foreach ($prop in $current.platforms.PSObject.Properties) {
				$mergedPlatforms[$prop.Name] = "$($prop.Value)"
			}
		}

		if ($null -ne $Platforms) {
			foreach ($key in $Platforms.Keys) {
				$mergedPlatforms["$key"] = "$($Platforms[$key])"
			}
		}

		$finalVersions = @()

		if ($null -ne $Versions) {
			$finalVersions = @($Versions)
		}
		elseif (-not $tenantChanged -and $null -ne $current -and $null -ne $current.versions) {
			$finalVersions = @($current.versions)
		}

		if ($finalVersions.Count -eq 0) { return }

		$payload = [ordered]@{
			refreshedUtc = [datetime]::UtcNow.ToString('o')
			tenantId     = "$($stamp.TenantId)"
			accountId    = "$($stamp.AccountId)"
			versions     = $finalVersions
			builds       = $mergedBuilds
			platforms    = $mergedPlatforms
		}

		$null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force -ErrorAction Stop
		$payload | ConvertTo-Json -Depth 6 -ErrorAction Stop | Set-Content -LiteralPath $path -Encoding utf8 -ErrorAction Stop
	}
	catch {
		Write-PSFMessage -Level Verbose -Message "FinOps version cache update skipped: $($_.Exception.Message)"
	}
}

function Clear-FinOpsVersionCache {
	<#
        .SYNOPSIS
            Evicts the cached version catalog.
        
        .DESCRIPTION
            Deletes the catalog cache file.
        
        .EXAMPLE
            PS C:\> Clear-FinOpsVersionCache
        
            Deletes the cached catalog.
        
        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	param ()

	try {
		$path = Get-FinOpsVersionCachePath

		if (Test-Path -LiteralPath $path) {
			Remove-Item -LiteralPath $path -Force -ErrorAction Stop
		}
	}
	catch {
		Write-PSFMessage -Level Verbose -Message "FinOps version cache eviction skipped: $($_.Exception.Message)"
	}
}
