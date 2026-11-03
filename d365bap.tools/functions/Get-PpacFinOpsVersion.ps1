
<#
    .SYNOPSIS
        Lists all published FinOps versions.

    .DESCRIPTION
        Queries the developer tools service for every published application track. No target environment is required.

    .PARAMETER AppVersion
        Track to show as version, track or full build. Omitted: everything.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .PARAMETER Oldest
        Returns only the oldest version.

    .PARAMETER Latest
        Returns only the latest version.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion

        Lists every published application track.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion -AsExcelOutput

        Lists every published application track into an Excel file.
        It uses -AsExcelOutput to write an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion -Latest

        Returns only the newest track.
        It uses -Latest to return only the newest track.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsVersion {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType('D365Bap.Tools.PpacFinOpsVersion[]', [object[]])]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string] $AppVersion,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[Parameter(ParameterSetName = "Lowest")]
		[switch] $Oldest,

		[Parameter(ParameterSetName = "Highest")]
		[switch] $Latest,

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
			$rawVersions = Invoke-RestMethod -Method Get `
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

		$colRes = @(
			$rawVersions |
			Sort-Object -Property { [version]$_.appVersion } |
			Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsVersion" `
				-Property `
				"appVersion as AppVersion", `
				"appBuild as AppBuild", `
			@{Name = "Track"; Expression = { "$($_.appBuild)" } }, `
				"platVersion as PlatVersion", `
				"platBuild as PlatBuild"
		)

		Write-FinOpsVersionCache -Versions $colRes

		if (-not [string]::IsNullOrWhiteSpace($AppVersion)) {
			$wantedTrack = Get-FinOpsTrackForAppVersion -Catalog $colRes `
				-AppVersion $AppVersion

			if ([string]::IsNullOrWhiteSpace($wantedTrack)) {
				$valid = ($colRes |
					Sort-Object -Property { [version]$_.AppVersion } |
					ForEach-Object { $_.AppVersion }) -join ", "
				$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid application versions are: $valid."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$colRes = @(
				$colRes |
				Where-Object { $_.AppBuild -eq $wantedTrack }
			)
		}

		$output = if ($Oldest) {
			$colRes |
			Select-Object -First 1
		}
		elseif ($Latest) {
			$colRes |
			Select-Object -Last 1
		}
		else {
			$colRes
		}

		if ($AsExcelOutput) {
			$output |
			Export-Excel -WorksheetName "Get-PpacFinOpsVersion" `
				-NoNumberConversion AppVersion, AppBuild, Track, PlatVersion, PlatBuild

			return
		}

		$output
	}
}
