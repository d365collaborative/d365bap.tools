<#
    .SYNOPSIS
        Warms the FinOps version cache on import.
        
    .DESCRIPTION
        Registers the background preload for the version catalog. All failures stay silent.
#>
[CmdletBinding()]
param()

function Start-FinOpsVersionPreload {
	<#
        .SYNOPSIS
            Warms the FinOps version cache in the background.
        
        .DESCRIPTION
            Starts a throttled background job that fetches the catalog. Results assign directly, never wrapped, as Invoke-RestMethod emits arrays non-enumerated.
        
        .PARAMETER MaxAgeHours
            Maximum cache age in hours before refetching.
            
            Default: 24
        
        .EXAMPLE
            PS C:\> Start-FinOpsVersionPreload
        
            Refreshes the cache when older than a day.
        
        .NOTES
            Author: Mötz Jensen (@Splaxi)
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseUsingScopeModifierInNewRunspaces", "", Justification = "Start-Job binds values through ArgumentList, the using scope modifier is not supported there.")]
	[CmdletBinding()]
	param (
		[int] $MaxAgeHours = 24
	)

	try {
		$azContext = Get-AzContext -ErrorAction SilentlyContinue
		if (-not $azContext) {
			$azCommand = Get-Command az -ErrorAction SilentlyContinue
			$azLoggedIn = $false
			if ($null -ne $azCommand) {
				$null = & az account show -o json 2>$null
				if ($LASTEXITCODE -eq 0) { $azLoggedIn = $true }
			}
			if (-not $azLoggedIn) {
				Write-PSFMessage -Level Verbose -Message 'FinOps version preload skipped: no Az login detected.'
				return
			}
		}

		if ($null -ne (Get-FinOpsVersionCache -MaxAgeHours $MaxAgeHours -ErrorAction SilentlyContinue)) { return }

		$runningPreload = Get-Job -Name 'd365bap.tools.finopsversion.preload' -ErrorAction SilentlyContinue | Where-Object State -eq 'Running'

		if ($runningPreload) { return }
		Get-Job -Name 'd365bap.tools.finopsversion.preload' -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

		$authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

		$null = Start-Job -Name 'd365bap.tools.finopsversion.preload' -ScriptBlock {
			param ([string] $CachePath, [string] $AuthProvider)

			try {
				if ($AuthProvider -eq 'AzCli') {
					$probe = & az account show -o json 2>$null
					if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace("$probe")) { return }
				}
				else {
					Import-Module Az.Accounts -ErrorAction Stop
					if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { return }
				}

				$bapToken = $null
				$tenantId = ''
				$accountId = ''

				if ($AuthProvider -eq 'AzCli') {
					$tokenRaw = & az account get-access-token --resource 'https://service.powerapps.com/' --query accessToken -o tsv 2>$null
					if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$tokenRaw")) { $bapToken = "$tokenRaw".Trim() }
					$accountRaw = & az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null
					if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$accountRaw")) {
						$accountObj = "$accountRaw" | ConvertFrom-Json -ErrorAction Stop
						$accountId = "$($accountObj.user)"
						$tenantId = "$($accountObj.tenant)"
					}
				}
				else {
					$bapTokenResult = Get-AzAccessToken -ResourceUrl 'https://service.powerapps.com/' -ErrorAction Stop
					$bapToken = $bapTokenResult.Token
					$jobContext = Get-AzContext -ErrorAction SilentlyContinue
					if ($null -ne $jobContext) {
						$accountId = "$($jobContext.Account.Id)"
						$tenantId = "$($jobContext.Tenant.Id)"
					}
				}

				if ([string]::IsNullOrWhiteSpace($bapToken)) { return }

				$envs = Invoke-RestMethod -Method Get `
					-Uri 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2023-06-01' `
					-Headers @{ Authorization = "Bearer $bapToken" } `
					-TimeoutSeconds 60 | `
					Select-Object -ExpandProperty value

				$finopsEnvs = @($envs | Where-Object { $null -ne $_.properties.linkedAppMetadata.type } | Sort-Object { $_.properties.displayName })

				if ($finopsEnvs.Count -eq 0) { return }

				$authEnvUri = ("$($finopsEnvs[0].properties.linkedEnvironmentMetadata.instanceUrl)" -replace 'com/', 'com').TrimEnd('/') + '/'

				$dataverseToken = $null

				if ($AuthProvider -eq 'AzCli') {
					$dvRaw = & az account get-access-token --resource $authEnvUri --query accessToken -o tsv 2>$null
					if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$dvRaw")) { $dataverseToken = "$dvRaw".Trim() }
				}
				else {
					$dvResult = Get-AzAccessToken -ResourceUrl $authEnvUri -ErrorAction Stop
					$dataverseToken = $dvResult.Token
				}

				if ([string]::IsNullOrWhiteSpace($dataverseToken)) { return }

				$devHeaders = @{
					Correlationid           = [guid]::NewGuid().ToString()
					Dataverseenvironmenturi = $authEnvUri.TrimEnd('/')
					Authorization           = "Bearer $dataverseToken"
					'Odata-Maxversion'      = '4.0'
					'Odata-Version'         = '4.0'
					Accept                  = 'application/json'
				}

				$versions = Invoke-RestMethod -Method Get `
					-Uri 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions' `
					-Headers $devHeaders `
					-TimeoutSeconds 60

				if ($null -eq $versions -or @($versions).Count -eq 0) { return }

				$builds = @{}

				foreach ($entry in $versions) {
					try {
						$trackDashed = "$($entry.appBuild)".Replace('.', '-')
						$trackBuilds = Invoke-RestMethod -Method Get `
							-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version=$trackDashed" `
							-Headers $devHeaders `
							-TimeoutSeconds 60

						if ($null -ne $trackBuilds -and @($trackBuilds).Count -gt 0) { $builds["$($entry.appBuild)"] = @($trackBuilds) }
					}
					catch { $null = $_.Exception.Message }
				}

				$payload = [ordered]@{
					refreshedUtc = [datetime]::UtcNow.ToString('o')
					tenantId     = "$tenantId"
					accountId    = "$accountId"
					versions     = $versions
					builds       = $builds
					platforms    = @{}
				}

				$null = New-Item -ItemType Directory -Path (Split-Path -Parent $CachePath) -Force -ErrorAction Stop
				$payload | ConvertTo-Json -Depth 6 -ErrorAction Stop | Set-Content -LiteralPath $CachePath -Encoding utf8 -ErrorAction Stop
			}
			catch { $null = $_.Exception.Message }
		} -ArgumentList @((Get-FinOpsVersionCachePath), $authProvider)
	}
	catch { Write-PSFMessage -Level Verbose -Message "FinOps version preload was skipped: $($_.Exception.Message)" }
}

Start-FinOpsVersionPreload
