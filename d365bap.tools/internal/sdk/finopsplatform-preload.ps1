
function Start-FinOpsPlatformPreload {
	<#
        .SYNOPSIS
            Warms the platform map for the newest tracks.

        .DESCRIPTION
            Starts a background job that fills the platform map for the newest tracks. Cached builds resolve their platform without extra lookups.

        .PARAMETER MaxAgeHours
            Maximum cache age in hours before refetching.

            Default: 24

        .EXAMPLE
            PS C:\> Start-FinOpsPlatformPreload

            Refreshes the platform map when older than a day.
            It uses -MaxAgeHours 24 to keep the map for one day.

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

			if (-not ($null -eq $azCommand)) {
				$previousExitCode = $global:LASTEXITCODE

				try {
					& az account show -o json 2>$null > $null

					if ($LASTEXITCODE -eq 0) { $azLoggedIn = $true }
				}
				finally {
					$global:LASTEXITCODE = $previousExitCode
				}
			}

			if (-not $azLoggedIn) {
				Write-PSFMessage -Level Verbose `
					-Message 'FinOps platform preload skipped: no Az login detected.'

				return
			}
		}

		$objCatalog = Get-FinOpsVersionCache -MaxAgeHours $MaxAgeHours `
			-ErrorAction SilentlyContinue

		$objSource = $objCatalog

		if ($null -eq $objSource) {
			$objSource = Read-FinOpsVersionCacheFile -ErrorAction SilentlyContinue
		}

		$startJob = $false

		if (($null -eq $objSource) `
				-or ($null -eq $objSource.versions)) {
			$startJob = $true
		}
		else {
			$colVersionRows = [System.Collections.Generic.List[object]]::new()

			foreach ($itemVersion in @($objSource.versions)) {
				if (-not ($null -eq $itemVersion.AppVersion)) {
					$tmpAppName = "$($itemVersion.AppVersion)"
					$tmpTrackName = "$($itemVersion.AppBuild)"
				}
				else {
					$tmpAppName = "$($itemVersion.appVersion)"
					$tmpTrackName = "$($itemVersion.appBuild)"
				}

				$tmpRow = [PsCustomObject][Ordered]@{
					Track = $tmpTrackName
					App   = $tmpAppName
				}

				$colVersionRows.Add($tmpRow)
			}

			$colTopTracks = @(
				$colVersionRows |
				Sort-Object -Property { [version]$_.App } `
					-Descending |
				Select-Object -ExpandProperty Track |
				Select-Object -First 3
			)

			foreach ($itemTrack in $colTopTracks) {
				$objBuildEntry = $null

				if (-not ($null -eq $objSource.builds)) {
					$objBuildEntry = $objSource.builds.PSObject.Properties["$itemTrack"]
				}

				if ($null -eq $objBuildEntry) {
					$startJob = $true
					break
				}

				foreach ($itemBuild in @($objBuildEntry.Value)) {
					if (($null -eq $objSource.platforms) `
							-or ($null -eq $objSource.platforms.PSObject.Properties["$itemBuild"])) {
						$startJob = $true
						break
					}
				}

				if ($startJob) { break }
			}

			if ((-not $startJob) `
					-and ($null -eq $objCatalog)) {
				$startJob = $true
			}
		}

		if (-not $startJob) { return }

		$colRunningPreload = Get-Job -Name 'd365bap.tools.finopsplatform.preload' `
			-ErrorAction SilentlyContinue |
		Where-Object State -eq 'Running'

		if ($colRunningPreload) { return }

		Get-Job -Name 'd365bap.tools.finopsplatform.preload' `
			-ErrorAction SilentlyContinue |
		Remove-Job -Force `
			-ErrorAction SilentlyContinue

		$authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'

		$apiVersion = $script:BapApiVersions.EnvironmentScopes

		Start-Job -Name 'd365bap.tools.finopsplatform.preload' `
			-ScriptBlock {
			param ([string] $CachePath, [string] $AuthProvider, [string] $ApiVersion)

			try {
				if ($AuthProvider -eq 'AzCli') {
					$probeAzCli = & az account show -o json 2>$null

					if (($LASTEXITCODE -ne 0) `
							-or ([string]::IsNullOrWhiteSpace($probeAzCli))) { return }
				}
				else {
					Import-Module Az.Accounts `
						-ErrorAction Stop

					if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { return }
				}

				$bapToken = $null
				$tenantId = ''
				$accountId = ''

				if ($AuthProvider -eq 'AzCli') {
					$tokenRaw = & az account get-access-token --resource 'https://service.powerapps.com/' --query accessToken -o tsv 2>$null

					if (($LASTEXITCODE -eq 0) `
							-and (-not [string]::IsNullOrWhiteSpace($tokenRaw))) { $bapToken = "$tokenRaw".Trim() }

					$accountRaw = & az account show --query '{user:user.name, tenant:tenantId}' -o json 2>$null

					if (($LASTEXITCODE -eq 0) `
							-and (-not [string]::IsNullOrWhiteSpace($accountRaw))) {
						$accountObj = "$accountRaw" |
						ConvertFrom-Json -ErrorAction Stop

						$accountId = "$($accountObj.user)"
						$tenantId = "$($accountObj.tenant)"
					}
				}
				else {
					$bapTokenResult = Get-AzAccessToken -ResourceUrl 'https://service.powerapps.com/' `
						-ErrorAction Stop

					if ($bapTokenResult.Token -is [System.Security.SecureString]) {
						$bapToken = ConvertFrom-SecureString -AsPlainText `
							-SecureString $bapTokenResult.Token
					}
					else {
						$bapToken = "$($bapTokenResult.Token)"
					}

					$jobContext = Get-AzContext -ErrorAction SilentlyContinue

					if (-not ($null -eq $jobContext)) {
						$accountId = "$($jobContext.Account.Id)"
						$tenantId = "$($jobContext.Tenant.Id)"
					}
				}

				if ([string]::IsNullOrWhiteSpace($bapToken)) { return }

				$hashBapHeaders = @{ Authorization = "Bearer $bapToken" }

				$colEnvs = Invoke-RestMethod -Method Get `
					-Uri ('https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version={0}' `
						-f $ApiVersion) `
					-Headers $hashBapHeaders `
					-ConnectionTimeoutSeconds 60 |
				Select-Object -ExpandProperty value

				$colFinopsEnvs = @(
					$colEnvs |
					Where-Object { -not ($null -eq $_.properties.linkedAppMetadata.type) } |
					Sort-Object { $_.properties.displayName }
				)

				if ($colFinopsEnvs.Count -eq 0) { return }

				$tmpAuthEnvUri = ("$($colFinopsEnvs[0].properties.linkedEnvironmentMetadata.instanceUrl)" -replace 'com/', 'com').TrimEnd('/') + '/'
				$dataverseToken = $null

				if ($AuthProvider -eq 'AzCli') {
					$dvRaw = & az account get-access-token --resource $tmpAuthEnvUri --query accessToken -o tsv 2>$null

					if (($LASTEXITCODE -eq 0) `
							-and (-not [string]::IsNullOrWhiteSpace($dvRaw))) { $dataverseToken = "$dvRaw".Trim() }
				}
				else {
					$dvResult = Get-AzAccessToken -ResourceUrl $tmpAuthEnvUri `
						-ErrorAction Stop

					if ($dvResult.Token -is [System.Security.SecureString]) {
						$dataverseToken = ConvertFrom-SecureString -AsPlainText `
							-SecureString $dvResult.Token
					}
					else {
						$dataverseToken = "$($dvResult.Token)"
					}
				}

				if ([string]::IsNullOrWhiteSpace($dataverseToken)) { return }

				$hashDevHeaders = @{
					Correlationid           = [guid]::NewGuid().ToString()
					Dataverseenvironmenturi = $tmpAuthEnvUri.TrimEnd('/')
					Authorization           = "Bearer $dataverseToken"
					'Odata-Maxversion'      = '4.0'
					'Odata-Version'         = '4.0'
					Accept                  = 'application/json'
				}

				$objVersionJob = Get-Job -Name 'd365bap.tools.finopsversion.preload' `
					-ErrorAction SilentlyContinue

				if (-not ($null -eq $objVersionJob)) {
					Wait-Job -Job $objVersionJob `
						-Timeout 600 > $null

					$objVersionJobState = $objVersionJob |
					Select-Object -ExpandProperty State


					if ($objVersionJobState -contains 'Running') { return }
				}

				$objState = $null

				try {
					$objState = Get-Content -LiteralPath $CachePath `
						-Raw `
						-Encoding utf8 `
						-ErrorAction Stop |
					ConvertFrom-Json -ErrorAction Stop
				}
				catch { return }

				$colSourceVersions = @()

				if ((-not ($null -eq $objState)) `
						-and (-not ($null -eq $objState.versions))) {
					$colSourceVersions = @($objState.versions)
				}
				else {
					try {
						$tmpLiveVersions = Invoke-RestMethod -Method Get `
							-Uri 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions' `
							-Headers $hashDevHeaders `
							-ConnectionTimeoutSeconds 60
					}
					catch { return }

					if ($null -eq $tmpLiveVersions) { return }

					$colSourceVersions = @($tmpLiveVersions)
				}

				if ($colSourceVersions.Count -eq 0) { return }

				$colJobRows = [System.Collections.Generic.List[object]]::new()

				foreach ($itemVersion in @($colSourceVersions)) {
					if (-not ($null -eq $itemVersion.AppVersion)) {
						$tmpAppName = "$($itemVersion.AppVersion)"
						$tmpTrackName = "$($itemVersion.AppBuild)"
					}
					else {
						$tmpAppName = "$($itemVersion.appVersion)"
						$tmpTrackName = "$($itemVersion.appBuild)"
					}

					$tmpRow = [PsCustomObject][Ordered]@{
						Track = $tmpTrackName
						App   = $tmpAppName
					}

					$colJobRows.Add($tmpRow)
				}

				$colTopTracks = @(
					$colJobRows |
					Sort-Object -Property { [version]$_.App } `
						-Descending |
					Select-Object -ExpandProperty Track |
					Select-Object -First 3
				)

				$hashBuilds = @{}

				if (-not ($null -eq $objState.builds)) {
					foreach ($itemProperty in $objState.builds.PSObject.Properties) {
						$hashBuilds["$($itemProperty.Name)"] = @($itemProperty.Value)
					}
				}

				foreach ($itemTrack in $colTopTracks) {
					if ((-not $hashBuilds.ContainsKey($itemTrack)) `
							-or (@($hashBuilds[$itemTrack]).Count -eq 0)) {
						try {
							$tmpLiveBuilds = Invoke-RestMethod -Method Get `
								-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}' `
									-f $itemTrack.Replace('.', '-')) `
								-Headers $hashDevHeaders `
								-ConnectionTimeoutSeconds 60
						}
						catch { continue }

						if ($null -eq $tmpLiveBuilds) {
							$hashBuilds[$itemTrack] = @()
						}
						else {
							$hashBuilds[$itemTrack] = @($tmpLiveBuilds)
						}
					}
				}

				$hashPlatforms = @{}
				$keepPrior = (-not ($null -eq $objState.platforms)) -and (($null -eq $objState.tenantId) -or ("$($objState.tenantId)" -eq $tenantId))

				if ($keepPrior) {
					foreach ($itemProperty in $objState.platforms.PSObject.Properties) {
						$hashPlatforms["$($itemProperty.Name)"] = "$($itemProperty.Value)"
					}
				}

				$colMissingBuilds = [System.Collections.Generic.List[object]]::new()

				foreach ($itemTrack in $colTopTracks) {
					foreach ($itemBuild in @($hashBuilds[$itemTrack])) {
						if ([string]::IsNullOrWhiteSpace($itemBuild)) { continue }

						if (-not $hashPlatforms.ContainsKey("$itemBuild")) {
							$tmpEntry = [PsCustomObject][Ordered]@{
								Build   = "$itemBuild"
								Headers = $hashDevHeaders
							}

							$colMissingBuilds.Add($tmpEntry)
						}
					}
				}

				if ($colMissingBuilds.Count -gt 0) {
					$colPlatResults = @(
						$colMissingBuilds |
						ForEach-Object -Parallel {
							$tmpEntry = $_
							$tmpDashed = "$($tmpEntry.Build)".Replace('.', '-')

							try {
								$tmpPlat = Invoke-RestMethod -Method Get `
									-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
										-f $tmpDashed) `
									-Headers $tmpEntry.Headers `
									-ConnectionTimeoutSeconds 60
							}
							catch {
								$tmpPlat = $null
							}

							if ([string]::IsNullOrWhiteSpace($tmpPlat)) { return }

							$tmpResult = [PsCustomObject][Ordered]@{
								Build    = "$($tmpEntry.Build)"
								Platform = "$tmpPlat"
							}

							$tmpResult
						} -ThrottleLimit 10
					)

					foreach ($itemResult in @($colPlatResults)) {
						if ($null -eq $itemResult) { continue }

						$hashPlatforms["$($itemResult.Build)"] = "$($itemResult.Platform)"
					}
				}

				$hashFinalBuilds = @{}

				if (-not ($null -eq $objState.builds)) {
					foreach ($itemProperty in $objState.builds.PSObject.Properties) {
						$hashFinalBuilds["$($itemProperty.Name)"] = @($itemProperty.Value)
					}
				}

				foreach ($itemTrack in @($hashBuilds.Keys)) {
					$hashFinalBuilds[$itemTrack] = @($hashBuilds[$itemTrack])
				}

				$hashPayload = [ordered]@{
					refreshedUtc = [datetime]::UtcNow.ToString('o')
					tenantId     = "$tenantId"
					accountId    = "$accountId"
					versions     = $colSourceVersions
					builds       = $hashFinalBuilds
					platforms    = $hashPlatforms
				}

				New-Item -ItemType Directory `
					-Path (Split-Path -Parent $CachePath) `
					-Force `
					-ErrorAction Stop > $null

				$hashPayload |
				ConvertTo-Json -Depth 6 `
					-ErrorAction Stop |
				Set-Content -LiteralPath $CachePath `
					-Encoding utf8 `
					-ErrorAction Stop
			}
			catch { return }
		} `
			-ArgumentList @((Get-FinOpsVersionCachePath), $authProvider, $apiVersion) > $null
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "FinOps platform preload was skipped: $($_.Exception.Message)"
	}
}

Start-FinOpsPlatformPreload
