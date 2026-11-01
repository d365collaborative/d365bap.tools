<#
    .SYNOPSIS
        Resolves the connectivity environment route.

    .DESCRIPTION
        Resolves an environment name or GUID to the identifier and display name
        used by the connectivity routes, including the default environment.

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
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	$envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1
	if ($null -ne $envObj) {
		return [pscustomobject]@{
			RouteId   = $envObj.PpacEnvId
			RouteName = $envObj.PpacEnvName
		}
	}

	$routeId = $null
	$routeName = $EnvironmentId

	if ($EnvironmentId -match '^Default-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
		$routeId = $EnvironmentId
	}
	else {
		$environmentGuid = [guid]::Empty
		if ([guid]::TryParse($EnvironmentId, [ref]$environmentGuid)) {
			$tenantId = $null
			try { $tenantId = (Get-BapContext).TenantId } catch { $tenantId = $null }

			if (-not [string]::IsNullOrWhiteSpace("$tenantId") -and $environmentGuid -eq [guid]$tenantId) {
				$routeId = "Default-$tenantId"
			}
			else {
				$routeId = "$environmentGuid"
			}
		}
	}

	if ([string]::IsNullOrWhiteSpace("$routeId")) { return $null }

	[pscustomobject]@{
		RouteId   = $routeId
		RouteName = $routeName
	}
}
