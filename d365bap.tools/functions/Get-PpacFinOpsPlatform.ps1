
<#
    .SYNOPSIS
        Resolves the platform version of a build.

    .DESCRIPTION
        Queries the developer tools service for the platform version of one application release.

    .PARAMETER AppVersion
        Track to resolve as version, track or full build. Omitted: derived from -Build.

    .PARAMETER Build
        Full build, track or short form. Omitted: newest build of the track.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -AppVersion "10.0.49"

        Shows the platform version of the newest 10.0.49 build.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -Build "10.0.2790.46"

        Shows the platform version of that build.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsBuild -Latest | Get-PpacFinOpsPlatform

        Shows the platform version of the newest build.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsPlatform -Build "10.0.2790.46" -AsExcelOutput

        Shows the platform version of that build into an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsPlatform {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string] $AppVersion,

		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string] $Build,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
		$appGiven = $PSBoundParameters.ContainsKey('AppVersion') -and -not [string]::IsNullOrWhiteSpace($AppVersion)

		if ($buildGiven -and $appGiven -and "$Build" -like '@{*}') {
			$Build = ''
			$buildGiven = $false
		}

		if (-not $buildGiven -and -not $appGiven) {
			$messageString = "Specify <c='em'>-Build</c> or <c='em'>-AppVersion</c>. A full build (10.0.2790.46), a track (10.0.2790) or an application version (10.0.49) is accepted."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because neither build nor application track was specified." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (-not $buildGiven) { $Build = $AppVersion }

		$ctx = Get-DevToolsAuthContext -EnvironmentId $EnvironmentId

		if ($null -eq $ctx) { return }

		$headers = @{
			"Correlationid"           = [guid]::NewGuid().ToString()
			"Dataverseenvironmenturi" = $ctx.Env.PpacEnvUri
			"Authorization"           = "Bearer $($ctx.Token)"
			"Odata-Maxversion"        = "4.0"
			"Odata-Version"           = "4.0"
			"Accept"                  = "application/json"
		}

		$normalized = "$Build".Replace("-", ".").Trim()
		$parts = @($normalized -split "\.")
		$fullBuild = $null

		if ($parts.Count -eq 4) {
			$fullBuild = $normalized

			if ($appGiven -and $buildGiven) {
				try {
					$appCatalog = Invoke-RestMethod -Method Get `
						-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
						-Headers $headers
				}
				catch {
					$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
					Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
					Stop-PSFFunction -Message "Stopping because the finopsversions request failed." -ErrorRecord $_
					return
				}

				$appTrack = Get-FinOpsTrackForAppVersion -Catalog $appCatalog -AppVersion $AppVersion

				if ($null -ne $appTrack -and "$($parts[0]).$($parts[1]).$($parts[2])" -ne $appTrack) {
					$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
					return
				}
			}
		}
		elseif ($parts.Count -eq 3 -or $parts.Count -eq 2) {
			try {
				$catalog = Invoke-RestMethod -Method Get `
					-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
					-Headers $headers
			}
			catch {
				$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
				Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
				Stop-PSFFunction -Message "Stopping because the finopsversions request failed." -ErrorRecord $_
				return
			}

			$track = $null

			$byAppVersion = @($catalog | Where-Object { $_.appVersion -eq $normalized } | Select-Object -First 1)

			if ($byAppVersion.Count -gt 0) {
				$track = $byAppVersion[0].appBuild
			}
			else {
				$candidate = if ($parts.Count -eq 4) { "$($parts[0]).$($parts[1]).$($parts[2])" } else { $normalized }
				$byBuild = @($catalog | Where-Object { $_.appBuild -eq $candidate } | Select-Object -First 1)

				if ($byBuild.Count -gt 0) {
					$track = $byBuild[0].appBuild
				}
			}

			if ([string]::IsNullOrWhiteSpace($track)) {
				$valid = ($catalog | Sort-Object -Property { [version]$_.appVersion } | ForEach-Object { $_.appVersion }) -join ", "
				$messageString = "Unknown build or track <c='em'>$Build</c>. Valid application versions are: $valid."
				Write-PSFMessage -Level Important -Message $messageString
				Stop-PSFFunction -Message "Stopping because the build was not recognized." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
				return
			}

			if ($appGiven -and $buildGiven) {
				$appTrack = Get-FinOpsTrackForAppVersion -Catalog $catalog -AppVersion $AppVersion

				if ($null -eq $appTrack) {
					$valid = ($catalog | Sort-Object -Property { [version]$_.appVersion } | ForEach-Object { $_.appVersion }) -join ", "
					$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid application versions are: $valid."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
					return
				}

				if ($track -ne $appTrack) {
					$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
					return
				}
			}

			try {
				$trackBuilds = Invoke-RestMethod -Method Get `
					-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version=$($track.Replace('.', '-'))" `
					-Headers $headers
			}
			catch {
				$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
				Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
				Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." -ErrorRecord $_
				return
			}

			$fullBuild = @($trackBuilds | Sort-Object -Property { [version]$_ } -Descending | Select-Object -First 1)

			if ([string]::IsNullOrWhiteSpace("$fullBuild")) {
				$messageString = "No quality updates found for track <c='em'>$track</c>."
				Write-PSFMessage -Level Important -Message $messageString
				Stop-PSFFunction -Message "Stopping because no builds were returned." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
				return
			}
		}
		else {
			$messageString = "Build <c='em'>$Build</c> is not a valid version. Use a full build (10.0.2790.46), a track (10.0.2790) or an application version (10.0.49)."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because the build was not recognized." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		$buildDashed = "$fullBuild".Replace(".", "-")

		try {
			$platformVersion = Invoke-RestMethod -Method Get `
				-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version=$buildDashed" `
				-Headers $headers
		}
		catch {
			$messageString = "Failed retrieving the platform version for build <c='em'>$fullBuild</c> from the developer tools service."
			Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
			Stop-PSFFunction -Message "Stopping because the finopsplatbuild request failed." -ErrorRecord $_
			return
		}

		$finOpsInfo = Resolve-FinOpsVersionFromCache -Build "$fullBuild"

		$output = [PsCustomObject][Ordered]@{
			"AppVersion"      = if ($null -ne $finOpsInfo) { $finOpsInfo.AppVersion } else { '' }
			"AppBuild"        = if ($null -ne $finOpsInfo) { $finOpsInfo.AppBuild } else { '' }
			"Track"           = if ($null -ne $finOpsInfo) { $finOpsInfo.AppBuild } else { '' }
			"Build"           = "$fullBuild"
			"PlatformVersion" = "$platformVersion"
		} | Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsPlatform" `
			-Property *

		Write-FinOpsVersionCache -Platforms @{"$fullBuild" = "$platformVersion" }

		if ($AsExcelOutput) {
			$output | Export-Excel -WorksheetName "Get-PpacFinOpsPlatform" `
				-NoNumberConversion AppVersion, AppBuild, Track, Build, PlatformVersion
			return
		}

		$output
	}
}
