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
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		if (-not $PSCmdlet.ShouldProcess($PolicyId, 'Remove the ACP rule set')) { return }

		$null = Remove-PpacTenantRuleBasedPolicyRuleSet -PolicyId $PolicyId -RuleSetId 'ConnectorManagement' -Confirm:$false
		Get-PpacTenantAcpPolicy -PolicyId $PolicyId
	}
}
