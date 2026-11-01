<#
    .SYNOPSIS
        List tenant advanced connector policies.

    .DESCRIPTION
        Returns governance rule-based policies that contain a
        ConnectorManagement rule set.

        An expanded allowlist view is available when requested.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter.

        Default: *

    .PARAMETER ExpandConnectors
        Returns one row per allowed connector instead of one row per policy.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacTenantAcpPolicy

        Lists every advanced connector policy.

    .EXAMPLE
        PS C:\> Get-PpacTenantAcpPolicy -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns one policy by GUID or display name.
        It uses -PolicyId to select the policy.

    .EXAMPLE
        PS C:\> Get-PpacTenantAcpPolicy -ExpandConnectors

        Returns one row per allowed connector.
        It uses -ExpandConnectors to expand the allowlist.

    .EXAMPLE
        PS C:\> Get-PpacTenantAcpPolicy -AsExcelOutput

        Exports ACP policies to an Excel workbook.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacTenantAcpPolicy {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacTenantAcpPolicy[]', [object[]])]
	param (
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[switch] $ExpandConnectors,

		[switch] $AsExcelOutput
	)

	process {
		$hashParams = @{
			Kind     = 'Acp'
			PolicyId = $PolicyId
		}

		$colPolicies = @(Get-PpacTenantRuleBasedPolicy @hashParams)
		$colRes = @(ConvertTo-PpacAcpPolicy -Policy $colPolicies -TypeName 'D365Bap.Tools.PpacTenantAcpPolicy' -ExpandConnectors:$ExpandConnectors)

		if ($AsExcelOutput) {
			if ($colRes.Count -gt 0) {
				$colRes | Export-Excel -WorksheetName 'Get-PpacTenantAcpPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$colRes
	}
}
