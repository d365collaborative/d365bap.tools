<#
    .SYNOPSIS
        Resolves the platform version of a build.

    .DESCRIPTION
        Queries the developer tools service for the platform version of one application release.

    .PARAMETER AppVersion
        Track to resolve as version, track or full build. Omitted: derived from -Build.

    .PARAMETER Build
        Full build, track or short form. Omitted: newest build of the track.

    .PARAMETER PlatformVersion
        Platform filter with wildcards. Omitted: all platforms.

        Default: "*".

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -AppVersion "10.0.49"

        Shows the platform of the newest 10.0.49 build.
        It uses -AppVersion "10.0.49" to choose the track.
        It uses -EnvironmentId when omitted for the first FinOps environment.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -Build "10.0.2790.46"

        Shows the platform of that build.
        It uses -Build "10.0.2790.46" to select the build.
        It uses -EnvironmentId when omitted for the first FinOps environment.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -AppVersion "10.0.49" -PlatformVersion "7.0.8199.*"

        Shows builds on 10.0.49 with a matching platform.
        It uses -AppVersion "10.0.49" to choose the track.
        It uses -PlatformVersion "7.0.8199.*" to filter platforms.
        It uses -EnvironmentId when omitted for the first FinOps environment.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -Build "10.0.2790.46" -AsExcelOutput

        Shows the platform of that build in an Excel file.
        It uses -Build "10.0.2790.46" to select the build.
        It writes an Excel file with -AsExcelOutput.
        It uses -EnvironmentId when omitted for the first FinOps environment.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsPlatform {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacFinOpsPlatform[]')]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string] $AppVersion,

		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string] $Build,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[SupportsWildcards()]
		[string] $PlatformVersion = '*',

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[switch] $AsExcelOutput
	)

	process {
		$buildGiven = $PSBoundParameters.ContainsKey('Build') `
			-and -not [string]::IsNullOrWhiteSpace($Build)

		$appGiven = $PSBoundParameters.ContainsKey('AppVersion') `
			-and -not [string]::IsNullOrWhiteSpace($AppVersion)

		$platformGiven = $PSBoundParameters.ContainsKey('PlatformVersion') `
			-and -not [string]::IsNullOrWhiteSpace($PlatformVersion)

		if (($buildGiven) `
				-and ($appGiven) `
				-and ("$Build" -like '@{*}')) {
			$Build = ''
			$buildGiven = $false
		}

		if (($platformGiven) `
				-and (-not ($appGiven))) {
			$messageString = "Specify <c='em'>-AppVersion</c> when using <c='em'>-PlatformVersion</c>. A track (10.0.2790) or an application version (10.0.49) is accepted."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because no application track was specified for the platform filter." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		if ((-not ($buildGiven)) `
				-and (-not ($appGiven))) {
			$messageString = "Specify <c='em'>-Build</c> or <c='em'>-AppVersion</c>. A full build (10.0.2790.46), a track (10.0.2790) or an application version (10.0.49) is accepted."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because neither build nor application track was specified." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$hashCtx = Get-DevToolsAuthContext -EnvironmentId $EnvironmentId

		if ($null -eq $hashCtx) {
			return
		}

		$hashHeaders = @{
			"Correlationid"           = [guid]::NewGuid().ToString()
			"Dataverseenvironmenturi" = $hashCtx.Env.PpacEnvUri
			"Authorization"           = "Bearer $($hashCtx.Token)"
			"Odata-Maxversion"        = "4.0"
			"Odata-Version"           = "4.0"
			"Accept"                  = "application/json"
		}

		if ($platformGiven) {
			try {
				$catalog = Invoke-RestMethod -Method Get `
					-Uri 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions' `
					-Headers $hashHeaders
			}
			catch {
				$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
				Write-PSFMessage -Level Important `
					-Message $messageString `
					-ErrorRecord $_

				Stop-PSFFunction -Message "Stopping because the finopsversions request failed." `
					-ErrorRecord $_

				return
			}

			$appTrack = Get-FinOpsTrackForAppVersion -Catalog $catalog `
				-AppVersion $AppVersion

			if ($null -eq $appTrack) {
				$colValid = @(
					$catalog |
					Sort-Object -Property { [version]$_.appVersion } |
					ForEach-Object { $_.appVersion }
				)

				$valid = $colValid -join ", "
				$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid application versions are: $valid."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$objFullBuild = $null

			if ($buildGiven) {
				$normalized = "$Build".Replace("-", ".").Trim()

				$colParts = @($normalized -split "\.")

				if ($colParts.Count -eq 4) {
					$objFullBuild = $normalized

					if ("$($colParts[0]).$($colParts[1]).$($colParts[2])" -ne $appTrack) {
						$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
						Write-PSFMessage -Level Important `
							-Message $messageString

						Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
							-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

						return
					}
				}
				elseif (($colParts.Count -eq 3) `
						-or ($colParts.Count -eq 2)) {
					$buildTrack = Get-FinOpsTrackForAppVersion -Catalog $catalog `
						-AppVersion $normalized

					if ($null -eq $buildTrack) {
						$colValid = @(
							$catalog |
							Sort-Object -Property { [version]$_.appVersion } |
							ForEach-Object { $_.appVersion }
						)

						$valid = $colValid -join ", "
						$messageString = "Unknown build or track <c='em'>$Build</c>. Valid application versions are: $valid."
						Write-PSFMessage -Level Important `
							-Message $messageString

						Stop-PSFFunction -Message "Stopping because the build was not recognized." `
							-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

						return
					}

					if ($buildTrack -ne $appTrack) {
						$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
						Write-PSFMessage -Level Important `
							-Message $messageString

						Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
							-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

						return
					}
				}
				else {
					$messageString = "Build <c='em'>$Build</c> is not a valid version. Use a full build (10.0.2790.46), a track (10.0.2790) or an application version (10.0.49)."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the build was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}
			}

			$colTrackBuilds = @()

			if ($null -eq $objFullBuild) {
				try {
					$trackBuilds = Invoke-RestMethod -Method Get `
						-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}' `
							-f $appTrack.Replace('.', '-')) `
						-Headers $hashHeaders
				}
				catch {
					$messageString = "Failed retrieving FinOps builds for track <c='em'>$appTrack</c> from the developer tools service."
					Write-PSFMessage -Level Important `
						-Message $messageString `
						-ErrorRecord $_

					Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." `
						-ErrorRecord $_

					return
				}

				$colTrackBuilds = @(
					$trackBuilds |
					Sort-Object -Property { [version]$_ } `
						-Descending
				)

				if ($colTrackBuilds.Count -eq 0) {
					$messageString = "No quality updates found for track <c='em'>$appTrack</c>."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because no builds were returned." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}
			}
			else {
				$colTrackBuilds = @("$objFullBuild")
			}

			$tmpFilter = "$PlatformVersion".Replace("-", ".").Trim()

			$hashPlatforms = @{}

			$colResults = @(
				foreach ($itemBuild in $colTrackBuilds) {
					$tmpDashed = "$itemBuild".Replace(".", "-")

					try {
						$tmpPlatform = Invoke-RestMethod -Method Get `
							-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
								-f $tmpDashed) `
							-Headers $hashHeaders
					}
					catch {
						Write-PSFMessage -Level Warning `
							-Message "Skipping build <c='em'>$itemBuild</c>: the platform version could not be resolved." `
							-ErrorRecord $_

						continue
					}

					$tmpNormalized = "$tmpPlatform".Replace("-", ".").Trim()

					$hashPlatforms["$itemBuild"] = "$tmpPlatform"

					if ($tmpNormalized -like $tmpFilter) {
						$tmpFinOpsInfo = Resolve-FinOpsVersionFromCache -Build "$itemBuild"

						$tmpAppVersion = ($null -eq $tmpFinOpsInfo) ? '' : $tmpFinOpsInfo.AppVersion

						$tmpAppBuild = ($null -eq $tmpFinOpsInfo) ? '' : $tmpFinOpsInfo.AppBuild

						if ([string]::IsNullOrWhiteSpace($tmpAppVersion)) {
							$tmpEntry = @(
								$catalog |
								Where-Object { $_.appBuild -eq $appTrack } |
								Select-Object -First 1
							)

							if ($tmpEntry.Count -gt 0) {
								$tmpAppVersion = "$($tmpEntry[0].appVersion)"
								$tmpAppBuild = "$($tmpEntry[0].appBuild)"
							}
						}

						if ([string]::IsNullOrWhiteSpace($tmpAppBuild)) {
							$tmpAppBuild = $appTrack
						}

						[PsCustomObject][Ordered]@{
							"AppVersion"      = $tmpAppVersion
							"AppBuild"        = $tmpAppBuild
							"Track"           = $tmpAppBuild
							"Build"           = "$itemBuild"
							"PlatformVersion" = "$tmpPlatform"
						}
					}
				}
			)

			Write-FinOpsVersionCache -Platforms $hashPlatforms

			if ($colResults.Count -eq 0) {
				$messageString = "No builds on track <c='em'>$appTrack</c> match platform <c='em'>$PlatformVersion</c>."
				Write-PSFMessage -Level Important `
					-Message $messageString

				return
			}

			$output = $colResults |
			Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsPlatform" `
				-Property *

			if ($AsExcelOutput) {
				$output |
				Export-Excel -WorksheetName "Get-PpacFinOpsPlatform" `
					-NoNumberConversion AppVersion, AppBuild, Track, Build, PlatformVersion

				return
			}

			$output
			return
		}

		if (-not $buildGiven) {
			$Build = $AppVersion
		}

		$normalized = "$Build".Replace("-", ".").Trim()

		$colParts = @($normalized -split "\.")

		$objFullBuild = $null

		if ($colParts.Count -eq 4) {
			$objFullBuild = $normalized

			if (($appGiven) `
					-and ($buildGiven)) {
				try {
					$appCatalog = Invoke-RestMethod -Method Get `
						-Uri 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions' `
						-Headers $hashHeaders
				}
				catch {
					$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
					Write-PSFMessage -Level Important `
						-Message $messageString `
						-ErrorRecord $_

					Stop-PSFFunction -Message "Stopping because the finopsversions request failed." `
						-ErrorRecord $_

					return
				}

				$appTrack = Get-FinOpsTrackForAppVersion -Catalog $appCatalog `
					-AppVersion $AppVersion

				if ((-Not ($null -eq $appTrack)) `
						-and ("$($colParts[0]).$($colParts[1]).$($colParts[2])" -ne $appTrack)) {
					$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}
			}
		}
		elseif (($colParts.Count -eq 3) `
				-or ($colParts.Count -eq 2)) {
			try {
				$catalog = Invoke-RestMethod -Method Get `
					-Uri 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions' `
					-Headers $hashHeaders
			}
			catch {
				$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
				Write-PSFMessage -Level Important `
					-Message $messageString `
					-ErrorRecord $_

				Stop-PSFFunction -Message "Stopping because the finopsversions request failed." `
					-ErrorRecord $_

				return
			}

			$track = $null

			$colByAppVersion = @(
				$catalog |
				Where-Object { $_.appVersion -eq $normalized } |
				Select-Object -First 1
			)

			if ($colByAppVersion.Count -gt 0) {
				$track = $colByAppVersion[0].appBuild
			}
			else {
				$candidate = $normalized

				if ($colParts.Count -eq 4) {
					$candidate = "$($colParts[0]).$($colParts[1]).$($colParts[2])"
				}

				$colByBuild = @(
					$catalog |
					Where-Object { $_.appBuild -eq $candidate } |
					Select-Object -First 1
				)

				if ($colByBuild.Count -gt 0) {
					$track = $colByBuild[0].appBuild
				}
			}

			if ([string]::IsNullOrWhiteSpace($track)) {
				$colValid = @(
					$catalog |
					Sort-Object -Property { [version]$_.appVersion } |
					ForEach-Object { $_.appVersion }
				)

				$valid = $colValid -join ", "
				$messageString = "Unknown build or track <c='em'>$Build</c>. Valid application versions are: $valid."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the build was not recognized." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			if (($appGiven) `
					-and ($buildGiven)) {
				$appTrack = Get-FinOpsTrackForAppVersion -Catalog $catalog `
					-AppVersion $AppVersion

				if ($null -eq $appTrack) {
					$colValid = @(
						$catalog |
						Sort-Object -Property { [version]$_.appVersion } |
						ForEach-Object { $_.appVersion }
					)

					$valid = $colValid -join ", "
					$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid application versions are: $valid."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}

				if ($track -ne $appTrack) {
					$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}
			}

			try {
				$trackBuilds = Invoke-RestMethod -Method Get `
					-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}' `
						-f $track.Replace('.', '-')) `
					-Headers $hashHeaders
			}
			catch {
				$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
				Write-PSFMessage -Level Important `
					-Message $messageString `
					-ErrorRecord $_

				Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." `
					-ErrorRecord $_

				return
			}

			$colNewest = @(
				$trackBuilds |
				Sort-Object -Property { [version]$_ } `
					-Descending |
				Select-Object -First 1
			)

			$objFullBuild = "$($colNewest[0])"

			if ([string]::IsNullOrWhiteSpace($objFullBuild)) {
				$messageString = "No quality updates found for track <c='em'>$track</c>."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because no builds were returned." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}
		}
		else {
			$messageString = "Build <c='em'>$Build</c> is not a valid version. Use a full build (10.0.2790.46), a track (10.0.2790) or an application version (10.0.49)."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the build was not recognized." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$buildDashed = "$objFullBuild".Replace(".", "-")

		try {
			$platformVersion = Invoke-RestMethod -Method Get `
				-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
					-f $buildDashed) `
				-Headers $hashHeaders
		}
		catch {
			$messageString = "Failed retrieving the platform version for build <c='em'>$objFullBuild</c> from the developer tools service."
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-ErrorRecord $_

			Stop-PSFFunction -Message "Stopping because the finopsplatbuild request failed." `
				-ErrorRecord $_

			return
		}

		$hashFinOpsInfo = Resolve-FinOpsVersionFromCache -Build "$objFullBuild"

		$output = [PsCustomObject][Ordered]@{
			"AppVersion"      = ($null -eq $hashFinOpsInfo) ? '' : $hashFinOpsInfo.AppVersion
			"AppBuild"        = ($null -eq $hashFinOpsInfo) ? '' : $hashFinOpsInfo.AppBuild
			"Track"           = ($null -eq $hashFinOpsInfo) ? '' : $hashFinOpsInfo.AppBuild
			"Build"           = "$objFullBuild"
			"PlatformVersion" = "$platformVersion"
		} | Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsPlatform" `
			-Property *

		Write-FinOpsVersionCache -Platforms @{"$objFullBuild" = "$platformVersion" }

		if ($AsExcelOutput) {
			$output |
			Export-Excel -WorksheetName "Get-PpacFinOpsPlatform" `
				-NoNumberConversion AppVersion, AppBuild, Track, Build, PlatformVersion

			return
		}

		$output
	}
}
