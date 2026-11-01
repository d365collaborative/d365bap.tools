
<#
    .SYNOPSIS
        Gets environments in the cheapest shape a caller needs.

    .DESCRIPTION
        Returns BAP environments by default and only pays for richer shapes on request.
        When no environment matches, it stops execution with an actionable message so
        callers never need a null check.

    .PARAMETER EnvironmentId
        Environment name, GUID, or LCS id. Supports wildcards.

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
	[OutputType([PSCustomObject])]
	param (
		[SupportsWildcards()]
		[string] $EnvironmentId = '*',

		[Parameter(ParameterSetName = 'Unified', Mandatory = $true)]
		[switch] $Unified,

		[Parameter(ParameterSetName = 'Unified')]
		[switch] $VersionDetails
	)

	$result = if ($Unified) {
		if ($VersionDetails) {
			Get-UnifiedEnvironment -EnvironmentId $EnvironmentId
		}
		else {
			Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails
		}
	}
	else {
		Get-BapEnvironment -EnvironmentId $EnvironmentId
	}

	if ($null -eq $result -or @($result).Count -eq 0) {
		$messageString = "Could not find any environment matching <c='em'>$EnvironmentId</c>. Please verify the id or list the available environments using <c='em'>Get-BapEnvironment</c> or <c='em'>Get-UnifiedEnvironment</c>."
		Write-PSFMessage -Level Important -Message $messageString
		Stop-PSFFunction -Message "Stopping because no environment matched the supplied id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -EnableException $true
	}

	$result
}
