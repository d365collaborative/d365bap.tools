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
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$current = @(Get-PpacTenantAcpPolicy -PolicyId $PolicyId)
		if ($current.Count -eq 0) {
			Stop-PSFFunction -Message "No ACP policy matched '$PolicyId'."
			return
		}
		if ($current.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple ACP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyLabel = $current[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyLabel")) { $policyLabel = $current[0].PolicyId }

		if (-not $PSCmdlet.ShouldProcess($policyLabel, 'Remove the ACP rule set')) { return }

		$null = Remove-PpacTenantRuleBasedPolicyRuleSet -PolicyId $current[0].PolicyId -RuleSetId 'ConnectorManagement' -Confirm:$false
		Get-PpacTenantAcpPolicy -PolicyId $current[0].PolicyId
	}
}
