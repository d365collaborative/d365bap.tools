<#
    .SYNOPSIS
        List effective ACP policies for an environment.

    .DESCRIPTION
        Returns the advanced connector policy that applies to an environment,
        including a policy inherited from its environment group.

        An expanded allowlist view is available when requested.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter. Includes non-effective policies.

        Default: *

    .PARAMETER ExpandConnectors
        Returns one row per allowed connector instead of one row per policy.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentAcpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the advanced connector policy for the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentAcpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns a policy by GUID or display name, effective or not.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentAcpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -ExpandConnectors

        Returns one row per allowed connector.
        It uses -EnvironmentId to select the environment.
        It uses -ExpandConnectors to expand the allowlist.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentAcpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports the effective ACP policy to an Excel workbook.
        It uses -EnvironmentId to select the environment.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentAcpPolicy {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[switch] $ExpandConnectors,

		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$params = @{
			Kind          = 'Acp'
			EnvironmentId = $EnvironmentId
		}
		if ($PSBoundParameters.ContainsKey('PolicyId')) { $params.PolicyId = $PolicyId }

		$policies = @(Get-PpacEnvironmentRuleBasedPolicy @params)
		$resCol = @(ConvertTo-PpacAcpPolicy -Policy $policies -TypeName 'D365Bap.Tools.PpacEnvironmentAcpPolicy' -ExpandConnectors:$ExpandConnectors)

		if ($AsExcelOutput) {
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacEnvironmentAcpPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
