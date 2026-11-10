function Start-FinOpsVersionPreload {
	<#
        .SYNOPSIS
            Warms the FinOps version catalog.

        .DESCRIPTION
            Starts a background job that fetches the version catalog and every published build. Stored platform versions are kept.

        .PARAMETER MaxAgeHours
            Maximum cache age in hours before refetching.

            Default: 24

        .EXAMPLE
            PS C:\> Start-FinOpsVersionPreload

            Refreshes the catalog when older than a day.
            It uses -MaxAgeHours 24 to keep the catalog for one day.

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
				-Message 'FinOps version preload skipped: no login detected.'

			return
		}

		$objCatalog = Get-FinOpsVersionCache -MaxAgeHours $MaxAgeHours `
			-ErrorAction SilentlyContinue


		$cacheComplete = $false

		if ((-not ($null -eq $objCatalog)) `
				-and (-not ($null -eq $objCatalog.versions)) `
				-and (-not ($null -eq $objCatalog.builds))) {
			$cacheComplete = $true

			foreach ($itemVersion in @($objCatalog.versions)) {
				if (-not ($null -eq $itemVersion.AppVersion)) {
					$tmpTrackName = "$($itemVersion.AppBuild)"
				}
				else {
					$tmpTrackName = "$($itemVersion.appBuild)"
				}

				if ([string]::IsNullOrWhiteSpace($tmpTrackName)) {
					$cacheComplete = $false
					break
				}

				$objBuildEntry = $objCatalog.builds.PSObject.Properties["$tmpTrackName"]

				if ($null -eq $objBuildEntry) {
					$cacheComplete = $false
					break
				}
			}
		}

		if ($cacheComplete) { return }

		$colRunningPreload = Get-Job -Name 'd365bap.tools.finopsversion.preload' `
			-ErrorAction SilentlyContinue |
		Where-Object State -eq 'Running'

		if ($colRunningPreload) { return }

		Get-Job -Name 'd365bap.tools.finopsversion.preload' `
			-ErrorAction SilentlyContinue |
		Remove-Job -Force `
			-ErrorAction SilentlyContinue

		$cachePath = Get-FinOpsVersionCachePath
		$clientPath = Join-Path $script:ModuleRoot 'internal/sdk/finopsclient.ps1'
		$apiVersion = $script:BapApiVersions.EnvironmentScopes

		Start-Job -Name 'd365bap.tools.finopsversion.preload' `
			-ScriptBlock {
			. $using:clientPath

			if (-not (Test-FinOpsClientLogin -AuthProvider $using:authProvider)) { return }

			$hashCtx = Get-FinOpsClientAuthContext -AuthProvider $using:authProvider `
				-ApiVersion $using:apiVersion

			if ($null -eq $hashCtx) { return }

			$colVersions = Get-FinOpsClientCatalog -Headers $hashCtx.Headers

			if ($null -eq $colVersions) { return }

			$hashBuilds = @{}

			foreach ($itemVersion in @($colVersions)) {
				if (-not ($null -eq $itemVersion.AppVersion)) {
					$tmpTrackName = "$($itemVersion.AppBuild)"
				}
				else {
					$tmpTrackName = "$($itemVersion.appBuild)"
				}

				if ([string]::IsNullOrWhiteSpace($tmpTrackName)) { continue }

				$tmpBuilds = Get-FinOpsClientBuildList -Track $tmpTrackName `
					-Headers $hashCtx.Headers


				if ($null -eq $tmpBuilds) { continue }

				$hashBuilds[$tmpTrackName] = @($tmpBuilds)
			}

			Write-FinOpsClientCache -Path $using:cachePath `
				-Versions @($colVersions) `
				-Builds $hashBuilds `
				-TenantId $hashCtx.TenantId `
				-AccountId $hashCtx.AccountId
		}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "FinOps version preload was skipped: $($_.Exception.Message)"

	}
}

Start-FinOpsVersionPreload
