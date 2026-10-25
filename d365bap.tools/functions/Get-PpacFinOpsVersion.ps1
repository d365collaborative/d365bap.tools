
<#
    .SYNOPSIS
        Lists all published FinOps versions.

    .DESCRIPTION
        Queries the developer tools service for every published application track. No target environment is needed.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .PARAMETER Oldest
        Returns only the oldest version.

    .PARAMETER Latest
        Returns only the latest version.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion

        Lists every published application track.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsVersion -Latest

        Returns only the newest track.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsVersion {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType('System.Object[]')]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[Parameter(ParameterSetName = "Lowest")]
		[switch] $Oldest,

		[Parameter(ParameterSetName = "Highest")]
		[switch] $Latest
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
			$rawVersions = Invoke-RestMethod -Method Get `
				-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
				-Headers $headers
		}
		catch {
			$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
			Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
			Stop-PSFFunction -Message "Stopping because the finopsversions request failed." -ErrorRecord $_
			return
		}

		$resCol = @(
			$rawVersions | Sort-Object -Property { [version]$_.appVersion } | `
				Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsVersion" `
				-Property `
				"appVersion as AppVersion", `
				"appBuild as AppBuild", `
				"platVersion as PlatVersion", `
				"platBuild as PlatBuild"
		)

		Write-FinOpsVersionCache -Versions $resCol

		if ($Oldest) {
			$resCol | Select-Object -First 1
		}
		elseif ($Latest) {
			$resCol | Select-Object -Last 1
		}
		else {
			$resCol
		}
	}
}
