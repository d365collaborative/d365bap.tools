<#
    .SYNOPSIS
        Resolve the DLP environment route and name.

    .DESCRIPTION
        Resolves an environment name or GUID to the identifier used by the
        classic DLP policy routes, including the default environment. The
        display name is returned for confirmation prompts.

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
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	$objRoute = [pscustomobject]@{
		RouteId = $null
		Name    = $EnvironmentId
	}

	$envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1
	if ($null -ne $envObj) {
		$objRoute.RouteId = "$($envObj.PpacEnvId)"
		if (-not [string]::IsNullOrWhiteSpace("$($envObj.PpacEnvName)")) {
			$objRoute.Name = $envObj.PpacEnvName
		}
		return $objRoute
	}

	if ($EnvironmentId -match '^Default-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
		$objRoute.RouteId = $EnvironmentId
		return $objRoute
	}

	$environmentGuid = [guid]::Empty
	if ([guid]::TryParse($EnvironmentId, [ref]$environmentGuid)) {
		$tenantId = $null
		try { $tenantId = (Get-BapContext).TenantId } catch { $tenantId = $null }
		if (-not [string]::IsNullOrWhiteSpace("$tenantId") -and $environmentGuid -eq [guid]$tenantId) {
			$objRoute.RouteId = "Default-$tenantId"
			return $objRoute
		}
		$objRoute.RouteId = "$environmentGuid"
		return $objRoute
	}

	$objRoute.RouteId = $null
	$objRoute
}
