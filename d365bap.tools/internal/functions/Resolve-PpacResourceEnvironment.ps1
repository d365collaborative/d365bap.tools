<#
    .SYNOPSIS
        Resolves environment routing details for resource APIs.

    .DESCRIPTION
        Routes explicit environment IDs without legacy discovery. Names and wildcards use the existing environment lookup. Explicit IDs are also used as display labels.

    .PARAMETER EnvironmentId
        Environment GUID, default environment ID, name, or wildcard.

    .EXAMPLE
        PS C:\> Resolve-PpacResourceEnvironment -EnvironmentId '00000000-0000-0000-0000-000000000000'

        Returns routing details without listing legacy environments.
        It uses -EnvironmentId to select the resource.
#>
function Resolve-PpacResourceEnvironment {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	$environmentKey = $EnvironmentId.Trim()
	$parsedId = [guid]::Empty
	if ([guid]::TryParse(($environmentKey -replace '^Default-', ''), [ref]$parsedId)) {
		[PSCustomObject][ordered]@{
			PpacEnvId   = $environmentKey
			EnvId       = $environmentKey
			PpacEnvName = $environmentKey
			EnvName     = $environmentKey
		}
		return
	}

	$envObj = Get-Environment -EnvironmentId $EnvironmentId
	$envObj
}
