<#
    .SYNOPSIS
        Resolves the application build of a platform version.

    .DESCRIPTION
        Queries the developer tools service for the platform version of one application release. A full platform value alone resolves the matching application track.

    .PARAMETER AppVersion
        Track to resolve as version, track or full build. Omitted: derived from -Build.

    .PARAMETER Build
        Full build, track or short form. Omitted: newest build of the track.

    .PARAMETER PlatformVersion
        Platform build to resolve. Standalone needs four parts.

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
        PS C:\> Get-PpacFinOpsPlatform -PlatformVersion "7.0.8199.56"

        Shows the application build for that platform.
        It uses -PlatformVersion "7.0.8199.56" to select the platform.
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
	[CmdletBinding(DefaultParameterSetName = 'ByPlatform')]
	[OutputType('D365Bap.Tools.PpacFinOpsPlatform[]')]
	param (
		[Parameter(ParameterSetName = 'ByApp', ValueFromPipelineByPropertyName = $true)]
		[string] $AppVersion,

		[Parameter(ParameterSetName = 'ByApp', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string] $Build,

		[Parameter(ParameterSetName = 'ByApp', ValueFromPipelineByPropertyName = $true)]
		[Parameter(ParameterSetName = 'ByPlatform', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[SupportsWildcards()]
		[string] $PlatformVersion = '*',

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[switch] $AsExcelOutput
	)

	process {
		if ($PSCmdlet.ParameterSetName -eq 'ByPlatform') {
			$tmpFilter = "$PlatformVersion".Replace("-", ".").Trim()

			$colFilterParts = @("$tmpFilter" -split "\.")

			if (($colFilterParts.Count -ne 4) `
					-or ("$tmpFilter" -notmatch '^\d+\.\d+\.\d+\.\d+$')) {
				$messageString = "Specify a full platform build <c='em'>$PlatformVersion</c> with four parts, such as <c='em'>7.0.8199.56</c>. Tracks and wildcards are not supported."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the platform version is not a full build." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$tmpPlatTrack = "$($colFilterParts[0]).$($colFilterParts[1]).$($colFilterParts[2])"

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

			$objCache = Get-FinOpsVersionCache -ErrorAction SilentlyContinue

			if ($null -eq $objCache) {
				$objCache = Read-FinOpsVersionCacheFile -ErrorAction SilentlyContinue
			}

			$colCandidates = @()

			if ((-not ($null -eq $objCache)) `
					-and (-not ($null -eq $objCache.versions))) {
				$colCandidates = @(
					$objCache.versions |
					Where-Object {
						$tmpVerPlat = (-not ($null -eq $_.PlatBuild)) ? "$($_.PlatBuild)" : "$($_.platBuild)"

						($tmpVerPlat -eq $tmpPlatTrack)
					}
				)
			}

			$colLiveVersions = $null

			if ($colCandidates.Count -eq 0) {
				try {
					$liveCatalog = Invoke-RestMethod -Method Get `
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

				$colLiveVersions = @($liveCatalog)

				$colCandidates = @(
					$liveCatalog |
					Where-Object { $_.platBuild -eq $tmpPlatTrack }
				)
			}

			if ($colCandidates.Count -eq 0) {
				$colValidCatalog = @()

				if (-not ($null -eq $colLiveVersions)) {
					$colValidCatalog = @($colLiveVersions)
				}
				elseif ((-not ($null -eq $objCache)) `
						-and (-not ($null -eq $objCache.versions))) {
					$colValidCatalog = @($objCache.versions)
				}

				$colValidPlat = @(
					$colValidCatalog |
					ForEach-Object {
						$tmpValidPlat = (-not ($null -eq $_.PlatBuild)) ? "$($_.PlatBuild)" : "$($_.platBuild)"

						$tmpValidPlat
					} | Sort-Object -Unique
				)

				$valid = $colValidPlat -join ", "
				$messageString = "Unknown platform <c='em'>$PlatformVersion</c>. Valid platform tracks are: $valid."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the platform was not recognized." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$hashKnownPlatforms = @{}

			if ((-not ($null -eq $objCache)) `
					-and (-not ($null -eq $objCache.platforms))) {
				foreach ($itemProp in $objCache.platforms.PSObject.Properties) {
					$hashKnownPlatforms["$($itemProp.Name)"] = "$($itemProp.Value)"
				}
			}

			$hashNewBuilds = @{}
			$hashNewPlatforms = @{}
			$colResults = [System.Collections.Generic.List[object]]::new()

			foreach ($itemCandidate in $colCandidates) {
				$tmpAppBuild = (-not ($null -eq $itemCandidate.AppBuild)) ? "$($itemCandidate.AppBuild)" : "$($itemCandidate.appBuild)"
				$tmpAppVersion = (-not ($null -eq $itemCandidate.AppVersion)) ? "$($itemCandidate.AppVersion)" : "$($itemCandidate.appVersion)"

				$tmpBuildList = @()

				if ((-not ($null -eq $objCache)) `
						-and (-not ($null -eq $objCache.builds)) `
						-and (-not ($null -eq $objCache.builds.PSObject.Properties[$tmpAppBuild]))) {
					$tmpBuildList = @($objCache.builds.PSObject.Properties[$tmpAppBuild].Value)
				}

				if ($tmpBuildList.Count -eq 0) {
					try {
						$tmpLiveBuilds = Invoke-RestMethod -Method Get `
							-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}' `
								-f $tmpAppBuild.Replace('.', '-')) `
							-Headers $hashHeaders
					}
					catch {
						Write-PSFMessage -Level Warning `
							-Message "Skipping track <c='em'>$tmpAppBuild</c>: the build list could not be retrieved." `
							-ErrorRecord $_

						continue
					}

					$tmpBuildList = @($tmpLiveBuilds)
					$hashNewBuilds[$tmpAppBuild] = @($tmpBuildList)
				}

				$tmpSortedBuilds = @(
					$tmpBuildList |
					Sort-Object -Property { [version]$_ }
				)

				$tmpMatchedBuilds = [System.Collections.Generic.List[string]]::new()
				$tmpScanNeeded = $false
				$tmpLow = 0
				$tmpHigh = $tmpSortedBuilds.Count - 1
				$tmpFound = -1
				$tmpBinaryOk = $true

				while ($tmpLow -le $tmpHigh) {
					$tmpMid = [int](($tmpLow + $tmpHigh) / 2)
					$tmpMidBuild = "$($tmpSortedBuilds[$tmpMid])"

					if (-not $hashKnownPlatforms.ContainsKey($tmpMidBuild)) {
						try {
							$tmpMidPlatRaw = Invoke-RestMethod -Method Get `
								-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
									-f $tmpMidBuild.Replace(".", "-")) `
								-Headers $hashHeaders
						}
						catch {
							Write-PSFMessage -Level Warning `
								-Message "Skipping build <c='em'>$tmpMidBuild</c>: the platform version could not be resolved." `
								-ErrorRecord $_

							$tmpBinaryOk = $false

							break
						}

						if ([string]::IsNullOrWhiteSpace($tmpMidPlatRaw)) {
							$tmpBinaryOk = $false

							break
						}

						$hashKnownPlatforms[$tmpMidBuild] = "$tmpMidPlatRaw"
						$hashNewPlatforms[$tmpMidBuild] = "$tmpMidPlatRaw"
					}

					$tmpMidNorm = "$($hashKnownPlatforms[$tmpMidBuild])".Replace("-", ".").Trim()

					if ("$tmpMidNorm" -eq "$tmpFilter") {
						$tmpFound = $tmpMid

						break
					}
					elseif ([version]$tmpMidNorm -lt [version]$tmpFilter) {
						$tmpLow = $tmpMid + 1
					}
					else {
						$tmpHigh = $tmpMid - 1
					}
				}

				if (($tmpFound -ge 0) `
						-and ($tmpBinaryOk)) {
					$tmpLeft = $tmpFound

					while ($tmpLeft -ge 0) {
						$tmpLeftBuild = "$($tmpSortedBuilds[$tmpLeft])"

						if (-not $hashKnownPlatforms.ContainsKey($tmpLeftBuild)) {
							try {
								$tmpLeftPlatRaw = Invoke-RestMethod -Method Get `
									-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
										-f $tmpLeftBuild.Replace(".", "-")) `
									-Headers $hashHeaders
							}
							catch {
								Write-PSFMessage -Level Warning `
									-Message "Skipping build <c='em'>$tmpLeftBuild</c>: the platform version could not be resolved." `
									-ErrorRecord $_

								break
							}

							if ([string]::IsNullOrWhiteSpace($tmpLeftPlatRaw)) {
								break
							}

							$hashKnownPlatforms[$tmpLeftBuild] = "$tmpLeftPlatRaw"
							$hashNewPlatforms[$tmpLeftBuild] = "$tmpLeftPlatRaw"
						}

						$tmpLeftNorm = "$($hashKnownPlatforms[$tmpLeftBuild])".Replace("-", ".").Trim()

						if ("$tmpLeftNorm" -eq "$tmpFilter") {
							$tmpMatchedBuilds.Add($tmpLeftBuild)
						}
						else {
							break
						}

						$tmpLeft--
					}

					$tmpRight = $tmpFound + 1

					while ($tmpRight -lt $tmpSortedBuilds.Count) {
						$tmpRightBuild = "$($tmpSortedBuilds[$tmpRight])"

						if (-not $hashKnownPlatforms.ContainsKey($tmpRightBuild)) {
							try {
								$tmpRightPlatRaw = Invoke-RestMethod -Method Get `
									-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
										-f $tmpRightBuild.Replace(".", "-")) `
									-Headers $hashHeaders
							}
							catch {
								Write-PSFMessage -Level Warning `
									-Message "Skipping build <c='em'>$tmpRightBuild</c>: the platform version could not be resolved." `
									-ErrorRecord $_

								break
							}

							if ([string]::IsNullOrWhiteSpace($tmpRightPlatRaw)) {
								break
							}

							$hashKnownPlatforms[$tmpRightBuild] = "$tmpRightPlatRaw"
							$hashNewPlatforms[$tmpRightBuild] = "$tmpRightPlatRaw"
						}

						$tmpRightNorm = "$($hashKnownPlatforms[$tmpRightBuild])".Replace("-", ".").Trim()

						if ("$tmpRightNorm" -eq "$tmpFilter") {
							$tmpMatchedBuilds.Add($tmpRightBuild)
						}
						else {
							break
						}

						$tmpRight++
					}
				}
				elseif ($tmpBinaryOk) {
					$tmpScanNeeded = $false
				}
				else {
					$tmpScanNeeded = $true
				}

				if ($tmpScanNeeded) {
					$tmpOrderedBuilds = @(
						$tmpSortedBuilds |
						Sort-Object -Property { [version]$_ } `
							-Descending
					)

					foreach ($itemBuild in $tmpOrderedBuilds) {
						if (-not $hashKnownPlatforms.ContainsKey("$itemBuild")) {
							try {
								$tmpFetchedPlat = Invoke-RestMethod -Method Get `
									-Uri ('https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}' `
										-f "$itemBuild".Replace(".", "-")) `
									-Headers $hashHeaders
							}
							catch {
								Write-PSFMessage -Level Warning `
									-Message "Skipping build <c='em'>$itemBuild</c>: the platform version could not be resolved." `
									-ErrorRecord $_

								continue
							}

							if ([string]::IsNullOrWhiteSpace($tmpFetchedPlat)) {
								continue
							}

							$hashKnownPlatforms["$itemBuild"] = "$tmpFetchedPlat"
							$hashNewPlatforms["$itemBuild"] = "$tmpFetchedPlat"
						}

						$tmpBuildPlat = "$($hashKnownPlatforms["$itemBuild"])".Replace("-", ".").Trim()

						if ("$tmpBuildPlat" -eq "$tmpFilter") {
							$tmpMatchedBuilds.Add("$itemBuild")
						}
					}
				}

				foreach ($itemMatch in $tmpMatchedBuilds) {
					$tmpResult = [PsCustomObject][Ordered]@{
						"AppVersion"      = $tmpAppVersion
						"AppBuild"        = $tmpAppBuild
						"Track"           = $tmpAppBuild
						"Build"           = "$itemMatch"
						"PlatformVersion" = "$($hashKnownPlatforms[$itemMatch])"
					}

					$colResults.Add($tmpResult)
				}
			}

			Write-FinOpsVersionCache -Versions $colLiveVersions `
				-Builds $hashNewBuilds `
				-Platforms $hashNewPlatforms


			if ($colResults.Count -eq 0) {
				$messageString = "No builds match platform <c='em'>$PlatformVersion</c>."
				Write-PSFMessage -Level Important `
					-Message $messageString

				return
			}

			$colOrderedResults = @(
				$colResults |
				Sort-Object -Property { [version]$_.Build } `
					-Descending
			)

			$output = $colOrderedResults |
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
