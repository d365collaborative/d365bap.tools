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

	$base = if ($env:APPDATA) {
		$env:APPDATA
	}
	else {
		Join-Path $HOME '.config'
	}

	Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'
}

function Read-FinOpsVersionCacheFile {
	<#
        .SYNOPSIS
            Reads the cached version catalog without validating the active login.

        .DESCRIPTION
            Returns the catalog as stored on disk, even when it was written under a different tenant or account.
            Local package labels use this view because the catalog only maps builds to application versions.
            A missing or unreadable file returns nothing.

        .PARAMETER Path
            Path to the cache file. Defaults to the FinOps version cache path.

        .EXAMPLE
            PS C:\> Read-FinOpsVersionCacheFile

            Returns the cached catalog without checking the active login.
            It will use the default -Path from Get-FinOpsVersionCachePath.

        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[string] $Path
	)

	if ([string]::IsNullOrWhiteSpace($Path)) {
		$Path = Get-FinOpsVersionCachePath
	}

	if (-not (Test-Path -LiteralPath $Path)) { return }

	try {
		$state = Get-Content -LiteralPath $Path `
			-Raw `
			-Encoding utf8 `
			-ErrorAction Stop |
		ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "Ignoring unreadable FinOps version cache at $Path : $($_.Exception.Message)"

		$null
		return
	}

	if ($null -eq $state.versions) { return }

	$state
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
		$provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'

		if ("$provider" -eq 'AzCli') {
			$raw = & az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null

			if (($LASTEXITCODE -eq 0) `
					-and (-not [string]::IsNullOrWhiteSpace($raw))) {
				$accountObj = $raw |
				ConvertFrom-Json -ErrorAction Stop
				$accountId = "$($accountObj.user)"
				$tenantId = "$($accountObj.tenant)"
			}
		}
		else {
			$azContext = Get-AzContext -ErrorAction SilentlyContinue

			if (-not ($null -eq $azContext)) {
				$accountId = "$($azContext.Account.Id)"
				$tenantId = "$($azContext.Tenant.Id)"
			}
		}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "FinOps version cache stamp unavailable: $($_.Exception.Message)"
	}

	@{
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
            The parsed catalog is reused for 60 seconds while the file is unchanged.

        .PARAMETER MaxAgeHours
            Maximum cache age in hours.

            Default: 24

        .EXAMPLE
            PS C:\> Get-FinOpsVersionCache

            Returns the cached catalog or null.
            It uses a -MaxAgeHours default of 24.

        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[int] $MaxAgeHours = 24
	)

	$path = Get-FinOpsVersionCachePath

	if ($null -eq $script:FinOpsVersionCacheMemo) {
		$script:FinOpsVersionCacheMemo = @{}
	}

	if (-not (Test-Path -LiteralPath $path)) {
		$script:FinOpsVersionCacheMemo = @{}
		$null
		return
	}

	try {
		$fileInfo = Get-Item -LiteralPath $path `
			-ErrorAction Stop
	}
	catch {
		$null
		return
	}

	$hashMemo = $script:FinOpsVersionCacheMemo

	if (-not ($null -eq $hashMemo.State)) {
		$tmpMemoAge = ([datetime]::UtcNow - $hashMemo.ValidatedUtc).TotalSeconds

		if (($tmpMemoAge -lt 60) `
				-and ("$($hashMemo.Path)" -eq "$path") `
				-and ($hashMemo.LastWriteUtc -eq $fileInfo.LastWriteTimeUtc) `
				-and ($hashMemo.Length -eq $fileInfo.Length) `
				-and (([datetime]::UtcNow - $hashMemo.RefreshedUtc).TotalHours -le $MaxAgeHours)) {
			$hashMemo.State
			return
		}
	}

	try {
		$state = Get-Content -LiteralPath $path `
			-Raw `
			-Encoding utf8 `
			-ErrorAction Stop |
		ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "Ignoring unreadable FinOps version cache at $path : $($_.Exception.Message)"

		$null
		return
	}

	if (($null -eq $state.refreshedUtc) `
			-or ($null -eq $state.versions)) {
		$null
		return
	}

	try {
		$refreshed = [datetime]$state.refreshedUtc
		$ageHours = ([datetime]::UtcNow - $refreshed.ToUniversalTime()).TotalHours
	}
	catch {
		$null
		return
	}

	if ($ageHours -gt $MaxAgeHours) { $null; return }

	$hashStamp = Get-FinOpsVersionCacheStamp

	if ((-not [string]::IsNullOrWhiteSpace($state.tenantId)) `
			-and (-not [string]::IsNullOrWhiteSpace($hashStamp.TenantId)) `
			-and ("$($state.tenantId)" -ne "$($hashStamp.TenantId)")) {
		$null
		return
	}

	if ((-not [string]::IsNullOrWhiteSpace($state.accountId)) `
			-and (-not [string]::IsNullOrWhiteSpace($hashStamp.AccountId)) `
			-and ("$($state.accountId)" -ne "$($hashStamp.AccountId)")) {
		$null
		return
	}

	$script:FinOpsVersionCacheMemo = @{
		Path         = "$path"
		LastWriteUtc = $fileInfo.LastWriteTimeUtc
		Length       = $fileInfo.Length
		ValidatedUtc = [datetime]::UtcNow
		RefreshedUtc = $refreshed.ToUniversalTime()
		State        = $state
	}

	$state
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
            It merges -Versions rows into the cache.

        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([void])]
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
				$current = Get-Content -LiteralPath $path `
					-Raw `
					-Encoding utf8 `
					-ErrorAction Stop |
				ConvertFrom-Json -ErrorAction Stop
			}
			catch {
				Write-PSFMessage -Level Verbose `
					-Message "Ignoring unreadable FinOps version cache at $path : $($_.Exception.Message)"

				$current = $null
			}
		}

		$hashStamp = Get-FinOpsVersionCacheStamp
		$tenantChanged = $false

		if ((-not ($null -eq $current)) `
				-and (-not [string]::IsNullOrWhiteSpace($current.tenantId)) `
				-and (-not [string]::IsNullOrWhiteSpace($hashStamp.TenantId)) `
				-and ("$($current.tenantId)" -ne "$($hashStamp.TenantId)")) {
			$tenantChanged = $true
		}

		if ((-not ($null -eq $current)) `
				-and (-not [string]::IsNullOrWhiteSpace($current.accountId)) `
				-and (-not [string]::IsNullOrWhiteSpace($hashStamp.AccountId)) `
				-and ("$($current.accountId)" -ne "$($hashStamp.AccountId)")) {
			$tenantChanged = $true
		}

		$hashMergedBuilds = @{}

		if ((-not $tenantChanged) `
				-and (-not ($null -eq $current)) `
				-and (-not ($null -eq $current.builds))) {
			foreach ($itemProperty in $current.builds.PSObject.Properties) {
				$hashMergedBuilds[$itemProperty.Name] = @($itemProperty.Value)
			}
		}

		if (-not ($null -eq $Builds)) {
			foreach ($itemKey in $Builds.Keys) {
				$hashMergedBuilds["$itemKey"] = @($Builds[$itemKey])
			}
		}

		$hashMergedPlatforms = @{}

		if ((-not $tenantChanged) `
				-and (-not ($null -eq $current)) `
				-and (-not ($null -eq $current.platforms))) {
			foreach ($itemProperty in $current.platforms.PSObject.Properties) {
				$hashMergedPlatforms[$itemProperty.Name] = "$($itemProperty.Value)"
			}
		}

		if (-not ($null -eq $Platforms)) {
			foreach ($itemKey in $Platforms.Keys) {
				$hashMergedPlatforms["$itemKey"] = "$($Platforms[$itemKey])"
			}
		}

		$colFinalVersions = @()

		if (-not ($null -eq $Versions)) {
			$colFinalVersions = @($Versions)
		}
		elseif ((-not $tenantChanged) `
				-and (-not ($null -eq $current)) `
				-and (-not ($null -eq $current.versions))) {
			$colFinalVersions = @($current.versions)
		}

		if ($colFinalVersions.Count -eq 0) { return }

		$hashPayload = [ordered]@{
			refreshedUtc = [datetime]::UtcNow.ToString('o')
			tenantId     = "$($hashStamp.TenantId)"
			accountId    = "$($hashStamp.AccountId)"
			versions     = $colFinalVersions
			builds       = $hashMergedBuilds
			platforms    = $hashMergedPlatforms
		}

		New-Item -ItemType Directory `
			-Path (Split-Path -Parent $path) `
			-Force `
			-ErrorAction Stop > $null

		$hashPayload |
		ConvertTo-Json -Depth 6 `
			-ErrorAction Stop |
		Set-Content -LiteralPath $path `
			-Encoding utf8 `
			-ErrorAction Stop

		$script:FinOpsVersionCacheMemo = @{}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "FinOps version cache update skipped: $($_.Exception.Message)"
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
	[OutputType([void])]
	param ()

	try {
		$path = Get-FinOpsVersionCachePath

		$script:FinOpsVersionCacheMemo = @{}

		if (Test-Path -LiteralPath $path) {
			Remove-Item -LiteralPath $path `
				-Force `
				-ErrorAction Stop
		}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "FinOps version cache eviction skipped: $($_.Exception.Message)"
	}
}

function Get-FinOpsTrackForAppVersion {
	<#
        .SYNOPSIS
            Resolves an application version to its track.

        .DESCRIPTION
            Maps a version string to its track.

        .PARAMETER Catalog
            Version catalog entries with appVersion and appBuild properties.

        .PARAMETER AppVersion
            Application version, track or full build to resolve.

        .EXAMPLE
            PS C:\> Get-FinOpsTrackForAppVersion -Catalog $catalog -AppVersion "10.0.49"

            Returns "10.0.2790".
            It matches -AppVersion against the catalog.
            It reads -Catalog rows with appVersion and appBuild properties.

        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		$Catalog,

		[string] $AppVersion
	)

	$normalized = "$AppVersion".Replace('-', '.').Trim()

	if ([string]::IsNullOrWhiteSpace($normalized)) { $null; return }

	$colByVer = @(
		$Catalog |
		Where-Object { $_.appVersion -eq $normalized } |
		Select-Object -First 1
	)

	if ($colByVer.Count -gt 0) { "$($colByVer[0].appBuild)"; return }

	$colParts = @($normalized -split '\.')
	$candidate = if ($colParts.Count -ge 3) {
		"$($colParts[0]).$($colParts[1]).$($colParts[2])"
	}
	else {
		$normalized
	}

	$colByBuild = @(
		$Catalog |
		Where-Object { $_.appBuild -eq $candidate } |
		Select-Object -First 1
	)

	if ($colByBuild.Count -gt 0) { "$($colByBuild[0].appBuild)"; return }

	$null
}

function Resolve-FinOpsVersionFromCache {
	<#
        .SYNOPSIS
            Maps a build to its catalog versions from cache.

        .DESCRIPTION
            Returns cached catalog metadata with an exact platform revision when available, without network calls.

        .PARAMETER Build
            Full build (10.0.2790.46), track (10.0.2790) or application version (10.0.49).

        .PARAMETER IgnoreStamp
            Use the on-disk catalog even when it was written under another login.

        .PARAMETER IncludePrerelease
            Return AppVersion "Prerelease" when the build is newer than every cached catalog track.

        .EXAMPLE
            PS C:\> Resolve-FinOpsVersionFromCache -Build "10.0.2790.46"

            Returns the catalog entry of track 10.0.2790.
            It resolves -Build to the cached catalog entry.

        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[string] $Build,

		[switch] $IgnoreStamp,

		[switch] $IncludePrerelease
	)

	$normalized = "$Build".Replace('-', '.').Trim()

	if ([string]::IsNullOrWhiteSpace($normalized)) { $null; return }

	$colParts = @($normalized -split '\.')
	$track = if ($colParts.Count -ge 3) {
		"$($colParts[0]).$($colParts[1]).$($colParts[2])"
	}
	else {
		$normalized
	}

	$objCached = if ($IgnoreStamp) {
		Read-FinOpsVersionCacheFile -ErrorAction SilentlyContinue
	}
	else {
		Get-FinOpsVersionCache -ErrorAction SilentlyContinue
	}

	if (($null -eq $objCached) `
			-or ($null -eq $objCached.versions)) { $null; return }

	$colEntry = @(
		$objCached.versions |
		Where-Object {
			$b = if (-not ($null -eq $_.AppBuild)) {
				"$($_.AppBuild)"
			}
			else {
				"$($_.appBuild)"
			}

			$b -eq $track
		} | Select-Object -First 1
	)

	if ($colEntry.Count -eq 0) {
		$colEntry = @(
			$objCached.versions |
			Where-Object {
				$v = if (-not ($null -eq $_.AppVersion)) {
					"$($_.AppVersion)"
				}
				else {
					"$($_.appVersion)"
				}

				$v -eq $normalized
			} | Select-Object -First 1
		)

		if ($colEntry.Count -eq 0) {
			if ($IncludePrerelease) {
				$maxTrack = $null

				foreach ($itemCacheEntry in @($objCached.versions)) {
					$trackText = if (-not ($null -eq $itemCacheEntry.AppBuild)) {
						"$($itemCacheEntry.AppBuild)"
					}
					else {
						"$($itemCacheEntry.appBuild)"
					}

					if ([string]::IsNullOrWhiteSpace($trackText)) { continue }

					try {
						$trackVersion = [version]$trackText
					}
					catch {
						continue
					}

					if (($null -eq $maxTrack) `
							-or ($trackVersion -gt $maxTrack)) {
						$maxTrack = $trackVersion
					}
				}

				$buildTrack = $null

				try {
					$buildTrack = [version]$track
				}
				catch {
					$buildTrack = $null
				}

				if ((-Not ($null -eq $maxTrack)) `
						-and (-Not ($null -eq $buildTrack)) `
						-and ($buildTrack -gt $maxTrack)) {
					@{
						AppVersion   = 'Prerelease'
						AppBuild     = ''
						PlatVersion  = ''
						PlatBuild    = ''
						IsPrerelease = $true
					}

					return
				}
			}

			$null
			return
		}
	}

	$e = $colEntry[0]
	$platBuild = (-not ($null -eq $e.PlatBuild)) ? "$($e.PlatBuild)" : "$($e.platBuild)"

	if ((-not ($null -eq $objCached.platforms)) `
			-and (-not ($null -eq $objCached.platforms.PSObject.Properties[$normalized]))) {
		$platBuild = "$($objCached.platforms.PSObject.Properties[$normalized].Value)"
	}

	@{
		AppVersion   = (-not ($null -eq $e.AppVersion)) ? "$($e.AppVersion)" : "$($e.appVersion)"
		AppBuild     = (-not ($null -eq $e.AppBuild)) ? "$($e.AppBuild)" : "$($e.appBuild)"
		PlatVersion  = (-not ($null -eq $e.PlatVersion)) ? "$($e.PlatVersion)" : "$($e.platVersion)"
		PlatBuild    = $platBuild
		IsPrerelease = $false
	}
}
