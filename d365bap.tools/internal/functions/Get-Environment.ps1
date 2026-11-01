
<#
    .SYNOPSIS
        Gets environments in the cheapest shape a caller needs.

    .DESCRIPTION
        Returns BAP environments by default. Extra data is fetched only when the
        caller opts in, because per-environment data costs seconds per environment.
        The default therefore stays a single environment list call.

    .PARAMETER EnvironmentId
        Environment name, GUID, or LCS id to match. Supports wildcards.

        Default: "*".

    .PARAMETER Unified
        Return unified environments instead of every BAP environment.

    .PARAMETER VersionDetails
        Include the per-environment provisioning data. Requires -Unified.

    .EXAMPLE
        PS C:\> Get-Environment -EnvironmentId "env-123"

        Returns the BAP environment without extra data.
        It uses -EnvironmentId to match name, GUID, or LCS id.

    .EXAMPLE
        PS C:\> Get-Environment -EnvironmentId "env-123" -Unified

        Returns the unified environment without extra data.
        It uses -EnvironmentId to match name, GUID, or LCS id.
        It uses -Unified to filter to unified environments.

    .EXAMPLE
        PS C:\> Get-Environment -EnvironmentId "env-123" -Unified -VersionDetails

        Returns the unified environment with provisioning data.
        It uses -EnvironmentId to match name, GUID, or LCS id.
        It uses -Unified to filter to unified environments.
        It uses -VersionDetails to include per-environment data.

    .NOTES
        Author: Motz Jensen (@Splaxi)
#>
function Get-Environment {
	[CmdletBinding(DefaultParameterSetName = 'Bap')]
	[OutputType('System.Object[]')]
	param (
		[SupportsWildcards()]
		[string] $EnvironmentId = '*',

		[Parameter(ParameterSetName = 'Unified', Mandatory = $true)]
		[switch] $Unified,

		[Parameter(ParameterSetName = 'Unified')]
		[switch] $VersionDetails
	)

	if ($Unified) {
		if ($VersionDetails) {
			return Get-UnifiedEnvironment -EnvironmentId $EnvironmentId
		}

		return Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails
	}

	return Get-BapEnvironment -EnvironmentId $EnvironmentId
}
