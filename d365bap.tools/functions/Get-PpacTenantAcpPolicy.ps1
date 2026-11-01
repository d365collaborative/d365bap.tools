<#
    .SYNOPSIS
        List tenant advanced connector policies.

    .DESCRIPTION
        Returns governance rule-based policies that contain a
        ConnectorManagement rule set.

        An expanded allowlist view is available when requested.

    .PARAMETER Name
        Policy id or display name filter. Wildcards are accepted.

        Default: *

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches return all matches.

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
	[OutputType('System.Object[]')]
	param (
		[SupportsWildcards()]
		[string] $Name = '*',

		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,
		[switch] $ExpandConnectors,
		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$params = @{ Kind = 'Acp' }
		if ($PSBoundParameters.ContainsKey('Name')) { $params.Name = $Name }
		if ($PSBoundParameters.ContainsKey('PolicyId') -and $PSBoundParameters.ContainsKey('Name')) {
			Stop-PSFFunction -Message "Specify -Name or -PolicyId, not both."
			return
		}

		if ($PSBoundParameters.ContainsKey('PolicyId')) { $params.PolicyId = $PolicyId }

		$policies = @(Get-PpacTenantRuleBasedPolicy @params)
		$resCol = @(ConvertTo-PpacAcpPolicy -Policy $policies -TypeName 'D365Bap.Tools.PpacTenantAcpPolicy' -ExpandConnectors:$ExpandConnectors)

		if ($AsExcelOutput) {
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacTenantAcpPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
