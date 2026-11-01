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

		if (-not $PSCmdlet.ShouldProcess($EnvironmentGroupId, "Assign ACP policy $PolicyId")) { return }

		$assigned = @(Add-PpacEnvironmentGroupRuleBasedPolicyAssignment -EnvironmentGroupId $EnvironmentGroupId -PolicyId $PolicyId -Confirm:$false)
		if ($assigned.Count -eq 0) { return }
		Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId $EnvironmentGroupId -PolicyId $PolicyId
	}
}
