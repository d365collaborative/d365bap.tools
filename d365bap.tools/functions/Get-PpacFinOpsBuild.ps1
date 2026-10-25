
<#
    .SYNOPSIS
        Lists quality updates for a FinOps track.

    .DESCRIPTION
        Queries the developer tools service for every published build of one application track.

    .PARAMETER AppVersion
        Track to list as version, build or full build. Omitted: newest track.

    .PARAMETER Latest
        Returns only the newest build.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsBuild -AppVersion "10.0.49"

        Lists all builds of the 10.0.49 track.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion -Latest | Get-PpacFinOpsBuild -Latest

        Lists the newest build of the newest track.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsBuild {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string] $AppVersion,

		[switch] $Latest,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

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
		$trackAppVersion = $null

		if ([string]::IsNullOrWhiteSpace($AppVersion)) {
			$entry = @($catalog | Sort-Object -Property { [version]$_.appVersion } | Select-Object -Last 1)

			if ($null -eq $entry) {
				Stop-PSFFunction -Message "Stopping because the version catalog is empty."
				return
			}

			$track = $entry.appBuild
			$trackAppVersion = $entry.appVersion
		}
		else {
			$normalized = "$AppVersion".Replace("-", ".").Trim()

			$byAppVersion = @($catalog | Where-Object { $_.appVersion -eq $normalized } | Select-Object -First 1)

			if ($byAppVersion.Count -gt 0) {
				$track = $byAppVersion[0].appBuild
				$trackAppVersion = $byAppVersion[0].appVersion
			}
			else {
				$parts = $normalized -split "\."

				if ($parts.Count -eq 4) {
					$candidate = "$($parts[0]).$($parts[1]).$($parts[2])"
					$byBuild = @($catalog | Where-Object { $_.appBuild -eq $candidate } | Select-Object -First 1)

					if ($byBuild.Count -gt 0) {
						$track = $byBuild[0].appBuild
						$trackAppVersion = $byBuild[0].appVersion
					}
				}
				elseif ($parts.Count -eq 3) {
					$byBuild = @($catalog | Where-Object { $_.appBuild -eq $normalized } | Select-Object -First 1)

					if ($byBuild.Count -gt 0) {
						$track = $byBuild[0].appBuild
						$trackAppVersion = $byBuild[0].appVersion
					}
				}

				if ([string]::IsNullOrWhiteSpace($track)) {
					$valid = ($catalog | Sort-Object -Property { [version]$_.appVersion } | ForEach-Object { $_.appVersion }) -join ", "
					$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid values are: $valid. Application builds ($($catalog[0].appBuild) style) and full builds are also accepted."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
					return
				}
			}
		}

		$trackDashed = $track.Replace(".", "-")

		try {
			$rawBuilds = Invoke-RestMethod -Method Get `
				-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version=$trackDashed" `
				-Headers $headers
		}
		catch {
			$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
			Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
			Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." -ErrorRecord $_
			return
		}

		if ($null -eq $rawBuilds -or @($rawBuilds).Count -eq 0) {
			$messageString = "No quality updates found for track <c='em'>$track</c>."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because no builds were returned." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		$resCol = @(
			$rawBuilds | Sort-Object -Property { [version]$_ } -Descending | `
				Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsBuild" `
				-Property `
			@{Name = "AppVersion"; Expression = { $trackAppVersion } }, `
			@{Name = "Track"; Expression = { $track } }, `
			@{Name = "Build"; Expression = { "$_" } }
		)

		Write-FinOpsVersionCache -Versions $catalog -Builds @{$track = @($rawBuilds) }

		if ($Latest) {
			$resCol | Select-Object -First 1
		}
		else {
			$resCol
		}
	}
}
