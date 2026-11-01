<#
    .SYNOPSIS
        Resolve the DLP environment route and name.

    .DESCRIPTION
        Resolves an environment name or GUID to the identifier used by the
        classic DLP policy routes. The display name is returned for
        confirmation prompts.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpRoute -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Returns the route identifier and display name for the environment.
        It uses -EnvironmentId to select the environment.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentDlpRoute {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	$envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1

	$objRoute = [pscustomobject]@{
		RouteId = $envObj.PpacEnvId
		Name    = $envObj.PpacEnvName
	}

	$objRoute
}
