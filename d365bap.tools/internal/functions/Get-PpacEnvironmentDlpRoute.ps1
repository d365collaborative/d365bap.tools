<#
    .SYNOPSIS
        Resolves the classic DLP environment route identifier.

    .DESCRIPTION
        Resolves an environment name or GUID to the identifier used by the
        classic DLP policy routes, including the default environment.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpRoute -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Returns the route identifier for the environment.
        It uses -EnvironmentId to select the environment.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentDlpRoute {
	[CmdletBinding()]
	[OutputType('System.String')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	$envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1
	if ($null -ne $envObj) { return "$($envObj.PpacEnvId)" }

	if ($EnvironmentId -match '^Default-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
		return $EnvironmentId
	}

	$environmentGuid = [guid]::Empty
	if ([guid]::TryParse($EnvironmentId, [ref]$environmentGuid)) {
		$tenantId = $null
		try { $tenantId = (Get-BapContext).TenantId } catch { $tenantId = $null }
		if (-not [string]::IsNullOrWhiteSpace("$tenantId") -and $environmentGuid -eq [guid]$tenantId) {
			return "Default-$tenantId"
		}
		return "$environmentGuid"
	}

	$null
}
