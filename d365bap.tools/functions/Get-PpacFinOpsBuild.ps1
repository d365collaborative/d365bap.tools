
<#
    .SYNOPSIS
        Lists quality updates for a FinOps track.

    .DESCRIPTION
        Queries the developer tools service for every published build of a single application track.

    .PARAMETER AppVersion
        Track to list as version, build or full build. Omitted: newest track.

    .PARAMETER Latest
        Returns only the newest build.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsBuild -AppVersion "10.0.49"

        Lists all builds of the 10.0.49 track.
        It uses -AppVersion to list one application track.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion -Latest | Get-PpacFinOpsBuild -Latest

        Lists the newest build of the newest track.
        It uses -Latest to limit the output to the newest build.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsBuild -AsExcelOutput

        Lists all builds of the newest track into an Excel file.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsBuild {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacFinOpsBuild[]', [object[]])]
	param (
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string] $AppVersion,

		[switch] $Latest,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[switch] $AsExcelOutput
	)

	process {
		$hashCtx = Get-DevToolsAuthContext -EnvironmentId $EnvironmentId

		if (Test-PSFFunctionInterrupt) { return }

		if ($null -eq $hashCtx) { return }

		$hashHeaders = @{
			"Correlationid"           = [guid]::NewGuid().ToString()
			"Dataverseenvironmenturi" = $hashCtx.Env.PpacEnvUri
			"Authorization"           = "Bearer $($hashCtx.Token)"
			"Odata-Maxversion"        = "4.0"
			"Odata-Version"           = "4.0"
			"Accept"                  = "application/json"
		}

		try {
			$catalog = Invoke-RestMethod -Method Get `
				-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
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
		$trackAppVersion = $null

		if ([string]::IsNullOrWhiteSpace($AppVersion)) {
			$colEntry = @(
				$catalog |
				Sort-Object -Property { [version]$_.appVersion } |
				Select-Object -Last 1
			)

			if ($null -eq $colEntry) {
				Stop-PSFFunction -Message "Stopping because the version catalog is empty."
				return
			}

			$track = $colEntry.appBuild
			$trackAppVersion = $colEntry.appVersion
		}
		else {
			$normalized = "$AppVersion".Replace("-", ".").Trim()

			$colByAppVersion = @(
				$catalog |
				Where-Object { $_.appVersion -eq $normalized } |
				Select-Object -First 1
			)

			if ($colByAppVersion.Count -gt 0) {
				$track = $colByAppVersion[0].appBuild
				$trackAppVersion = $colByAppVersion[0].appVersion
			}
			else {
				$parts = $normalized -split "\."

				if ($parts.Count -eq 4) {
					$candidate = "$($parts[0]).$($parts[1]).$($parts[2])"
					$colByBuild = @(
						$catalog |
						Where-Object { $_.appBuild -eq $candidate } |
						Select-Object -First 1
					)

					if ($colByBuild.Count -gt 0) {
						$track = $colByBuild[0].appBuild
						$trackAppVersion = $colByBuild[0].appVersion
					}
				}
				elseif ($parts.Count -eq 3) {
					$colByBuild = @(
						$catalog |
						Where-Object { $_.appBuild -eq $normalized } |
						Select-Object -First 1
					)

					if ($colByBuild.Count -gt 0) {
						$track = $colByBuild[0].appBuild
						$trackAppVersion = $colByBuild[0].appVersion
					}
				}

				if ([string]::IsNullOrWhiteSpace($track)) {
					$valid = (
						$catalog |
						Sort-Object -Property { [version]$_.appVersion } |
						ForEach-Object { $_.appVersion }
					) -join ", "
					$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid values are: $valid. Application builds ($($catalog[0].appBuild) style) and full builds are also accepted."

					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}
			}
		}

		$trackDashed = $track.Replace(".", "-")

		$buildUri = 'https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}' `
			-f $trackDashed

		try {
			$rawBuilds = Invoke-RestMethod -Method Get `
				-Uri $buildUri `
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

		if (($null -eq $rawBuilds) `
				-or (@($rawBuilds).Count -eq 0)) {
			$messageString = "No quality updates found for track <c='em'>$track</c>."

			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because no builds were returned." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colRes = @(
			$rawBuilds |
			Sort-Object -Property { [version]$_ } `
				-Descending |
			Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsBuild" `
				-Property `
			@{Name = "AppVersion"; Expression = { $trackAppVersion } },
			@{Name = "AppBuild"; Expression = { $track } },
			@{Name = "Track"; Expression = { $track } },
			@{Name = "Build"; Expression = { "$_" } }
		)

		Write-FinOpsVersionCache -Versions $catalog `
			-Builds @{$track = @($rawBuilds) }

		$output = if ($Latest) {
			$colRes |
			Select-Object -First 1
		}
		else {
			$colRes
		}

		if ($AsExcelOutput) {
			$output |
			Export-Excel -WorksheetName "Get-PpacFinOpsBuild" `
				-NoNumberConversion AppVersion, AppBuild, Track, Build

			return
		}

		$output
	}
}
