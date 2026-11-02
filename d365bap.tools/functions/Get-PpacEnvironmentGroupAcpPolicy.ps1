<#
    .SYNOPSIS
        List ACP policies for an environment group.

    .DESCRIPTION
        Returns advanced connector policies visible to an environment group.

        IsEffective shows whether a policy is assigned to the group. An expanded
        allowlist view is available when requested.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter.

        Default: *

    .PARAMETER ExpandConnectors
        Returns one row per allowed connector instead of one row per policy.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000"

        Lists the ACP policies for the group.
        It uses -EnvironmentGroupId to select the group.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns a policy by GUID or display name.
        It uses -EnvironmentGroupId to select the group.
        It uses -PolicyId to select the policy.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -ExpandConnectors

        Returns one row per allowed connector.
        It uses -EnvironmentGroupId to select the group.
        It uses -ExpandConnectors to expand the allowlist.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports the group ACP policy to an Excel workbook.
        It uses -EnvironmentGroupId to select the group.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentGroupAcpPolicy {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacEnvironmentGroupAcpPolicy[]', [object[]])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[switch] $ExpandConnectors,

		[switch] $AsExcelOutput
	)

	process {
		$colPolicies = @(Get-PpacEnvironmentGroupRuleBasedPolicy -Kind 'Acp' `
				-EnvironmentGroupId $EnvironmentGroupId `
				-PolicyId $PolicyId)

		$colRes = @(ConvertTo-PpacAcpPolicy -Policy $colPolicies `
				-TypeName 'D365Bap.Tools.PpacEnvironmentGroupAcpPolicy' `
				-ExpandConnectors:$ExpandConnectors)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentGroupAcpPolicy' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
