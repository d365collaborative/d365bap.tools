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
	[CmdletBinding()]
	param (
		[int] $MaxAgeHours = 24
	)

	try {
		$authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'

		if (-not (Test-FinOpsClientLogin -AuthProvider $authProvider)) {
			Write-PSFMessage -Level Verbose `
				-Message 'FinOps platform preload skipped: no login detected.'

			return
		}

		$objCatalog = Get-FinOpsVersionCache -MaxAgeHours $MaxAgeHours `
			-ErrorAction SilentlyContinue

		$objSource = $objCatalog

		if ($null -eq $objSource) {
			$objSource = Read-FinOpsClientCache -Path (Get-FinOpsVersionCachePath)
		}

		$colTopTracks = @()

		if ((-not ($null -eq $objSource)) `
				-and (-not ($null -eq $objSource.versions))) {
			$colTopTracks = Select-FinOpsTopTrack -Versions @($objSource.versions) `
				-Count 3
		}

		$startJob = ($null -eq $colTopTracks) `
			-or (@($colTopTracks).Count -eq 0)

		if (-not $startJob) {
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
		}

		if ((-not $startJob) `
				-and ($null -eq $objCatalog)) {
			$startJob = $true
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

		$cachePath = Get-FinOpsVersionCachePath
		$clientPath = Join-Path $script:ModuleRoot 'internal/sdk/finopsclient.ps1'
		$apiVersion = $script:BapApiVersions.EnvironmentScopes

		Start-Job -Name 'd365bap.tools.finopsplatform.preload' `
			-ScriptBlock {
			. $using:clientPath

			if (-not (Test-FinOpsClientLogin -AuthProvider $using:authProvider)) { return }

			$hashCtx = Get-FinOpsClientAuthContext -AuthProvider $using:authProvider `
				-ApiVersion $using:apiVersion

			if ($null -eq $hashCtx) { return }

			$objVersionJob = Get-Job -Name 'd365bap.tools.finopsversion.preload' `
				-ErrorAction SilentlyContinue

			if (-not ($null -eq $objVersionJob)) {
				Wait-Job -Job $objVersionJob `
					-Timeout 600 > $null

				$objVersionJobState = $objVersionJob |
				Select-Object -ExpandProperty State

				if ($objVersionJobState -contains 'Running') { return }
			}

			$objState = Read-FinOpsClientCache -Path $using:cachePath

			$colSourceVersions = @()

			if ((-not ($null -eq $objState)) `
					-and (-not ($null -eq $objState.versions))) {
				$colSourceVersions = @($objState.versions)
			}

			if ($colSourceVersions.Count -eq 0) {
				$tmpLiveVersions = Get-FinOpsClientCatalog -Headers $hashCtx.Headers

				if ($null -eq $tmpLiveVersions) { return }

				$colSourceVersions = @($tmpLiveVersions)
			}

			if ($colSourceVersions.Count -eq 0) { return }

			$colJobTracks = Select-FinOpsTopTrack -Versions $colSourceVersions `
				-Count 3

			if (($null -eq $colJobTracks) `
					-or (@($colJobTracks).Count -eq 0)) { return }

			$hashKnownPlatforms = @{}

			if (-not ($null -eq $objState)) {
				if (-not ($null -eq $objState.platforms)) {
					foreach ($itemProperty in $objState.platforms.PSObject.Properties) {
						$hashKnownPlatforms["$($itemProperty.Name)"] = "$($itemProperty.Value)"
					}
				}
			}

			$hashBuilds = @{}

			if (-not ($null -eq $objState)) {
				if (-not ($null -eq $objState.builds)) {
					foreach ($itemProperty in $objState.builds.PSObject.Properties) {
						$hashBuilds["$($itemProperty.Name)"] = @($itemProperty.Value)
					}
				}
			}

			foreach ($itemTrack in @($colJobTracks)) {
				if (-not $hashBuilds.ContainsKey($itemTrack)) {
					$tmpLiveBuilds = Get-FinOpsClientBuildList -Track $itemTrack `
						-Headers $hashCtx.Headers

					if ($null -eq $tmpLiveBuilds) { continue }

					$hashBuilds[$itemTrack] = @($tmpLiveBuilds)
				}
			}

			$colMissingBuilds = [System.Collections.Generic.List[object]]::new()

			foreach ($itemTrack in @($colJobTracks)) {
				if (-not $hashBuilds.ContainsKey($itemTrack)) { continue }

				foreach ($itemBuild in @($hashBuilds[$itemTrack])) {
					if ([string]::IsNullOrWhiteSpace($itemBuild)) { continue }

					if (-not $hashKnownPlatforms.ContainsKey("$itemBuild")) {
						$tmpEntry = [PsCustomObject][Ordered]@{
							Build   = "$itemBuild"
							Headers = $hashCtx.Headers
						}

						$colMissingBuilds.Add($tmpEntry)
					}
				}
			}

			$hashNewPlatforms = @{}

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

					$hashNewPlatforms["$($itemResult.Build)"] = "$($itemResult.Platform)"
				}
			}

			$hashNewBuilds = @{}

			foreach ($itemTrack in @($hashBuilds.Keys)) {
				$hashNewBuilds[$itemTrack] = @($hashBuilds[$itemTrack])
			}

			Write-FinOpsClientCache -Path $using:cachePath `
				-Versions $colSourceVersions `
				-Builds $hashNewBuilds `
				-Platforms $hashNewPlatforms `
				-TenantId $hashCtx.TenantId `
				-AccountId $hashCtx.AccountId
		}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "FinOps platform preload was skipped: $($_.Exception.Message)"

	}
}

Start-FinOpsPlatformPreload
