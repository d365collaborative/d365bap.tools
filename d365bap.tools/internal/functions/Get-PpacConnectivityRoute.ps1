<#
    .SYNOPSIS
        Resolves the connectivity environment route.

    .DESCRIPTION
        Resolves an environment name or GUID to the identifier and display name
        used by the connectivity routes.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .EXAMPLE
        PS C:\> Get-PpacConnectivityRoute -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Returns the route identifier and display name.
        It uses -EnvironmentId to select the environment.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacConnectivityRoute {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	$envObj = Get-Environment -EnvironmentId $EnvironmentId |
	Select-Object -First 1

	[pscustomobject][ordered]@{
		RouteId   = $envObj.PpacEnvId
		RouteName = $envObj.PpacEnvName
	}
}
