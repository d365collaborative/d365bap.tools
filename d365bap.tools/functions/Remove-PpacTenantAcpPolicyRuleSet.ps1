<#
    .SYNOPSIS
        Remove the ACP rule set from a tenant policy.

    .DESCRIPTION
        Removes the ConnectorManagement rule set from a governance policy
        through the Power Platform API.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Remove-PpacTenantAcpPolicyRuleSet -PolicyId "11111111-1111-1111-1111-111111111111"

        Removes the ACP rule set from the policy.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Remove-PpacTenantAcpPolicyRuleSet {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacTenantAcpPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		$colCurrent = @(Get-PpacTenantAcpPolicy -PolicyId $PolicyId)
		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No ACP policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple ACP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = 'Remove ACP policy rule set'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		Remove-PpacTenantRuleBasedPolicyRuleSet -PolicyId $colCurrent[0].PolicyId `
			-RuleSetId 'ConnectorManagement' `
			-Confirm:$false > $null

		Get-PpacTenantAcpPolicy -PolicyId $colCurrent[0].PolicyId
	}
}
