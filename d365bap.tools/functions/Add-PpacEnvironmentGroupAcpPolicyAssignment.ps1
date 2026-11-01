<#
    .SYNOPSIS
        Assign an ACP policy to an environment group.

    .DESCRIPTION
        Creates a governance policy assignment for an environment group and
        returns the resulting ACP policy.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Add-PpacEnvironmentGroupAcpPolicyAssignment -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Assigns the ACP policy to the group.
        It uses -EnvironmentGroupId to select the group.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Add-PpacEnvironmentGroupAcpPolicyAssignment {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$groupLabel = $EnvironmentGroupId
		try {
			$groupObj = Get-PpacEnvironmentGroup -EnvironmentGroup $EnvironmentGroupId | Select-Object -First 1
			if ($null -ne $groupObj -and -not [string]::IsNullOrWhiteSpace("$($groupObj.DisplayName)")) {
				$groupLabel = $groupObj.DisplayName
			}
		}
		catch {
			$groupLabel = $EnvironmentGroupId
		}

		$policy = @(Get-PpacTenantAcpPolicy -PolicyId $PolicyId)
		if ($policy.Count -eq 0) {
			Stop-PSFFunction -Message "No ACP policy matched '$PolicyId'."
			return
		}
		if ($policy.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple ACP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyLabel = $policy[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyLabel")) { $policyLabel = $policy[0].PolicyId }

		if (-not $PSCmdlet.ShouldProcess($policyLabel, "Assign ACP to group '$groupLabel'")) { return }

		$assigned = @(Add-PpacEnvironmentGroupRuleBasedPolicyAssignment -EnvironmentGroupId $EnvironmentGroupId -PolicyId $policy[0].PolicyId -Confirm:$false)
		if ($assigned.Count -eq 0) { return }
		Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId $EnvironmentGroupId -PolicyId $policy[0].PolicyId
	}
}
