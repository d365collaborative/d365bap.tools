<#
    .SYNOPSIS
        List ACP policies for an environment.

    .DESCRIPTION
        Returns advanced connector policies visible to an environment,
        including policies inherited from its environment group.

        IsEffective shows whether a policy applies to the environment. An
        expanded allowlist view is available when requested.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter.

        Default: *

    .PARAMETER ExpandConnectors
        Returns one row per allowed connector instead of one row per policy.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentAcpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the advanced connector policies for the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentAcpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns a policy by GUID or display name.
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
	[OutputType('D365Bap.Tools.PpacEnvironmentAcpPolicy[]', [object[]])]
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
		$colPolicies = @(Get-PpacEnvironmentRuleBasedPolicy -Kind 'Acp' `
				-EnvironmentId $EnvironmentId `
				-PolicyId $PolicyId)

		$colRes = @(ConvertTo-PpacAcpPolicy -Policy $colPolicies `
				-TypeName 'D365Bap.Tools.PpacEnvironmentAcpPolicy' `
				-ExpandConnectors:$ExpandConnectors)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentAcpPolicy' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
