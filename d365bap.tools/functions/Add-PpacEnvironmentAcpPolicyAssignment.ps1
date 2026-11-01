<#
    .SYNOPSIS
        Assign an ACP policy to an environment.

    .DESCRIPTION
        Creates a governance policy assignment for an environment and returns
        the resulting ACP policy.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Add-PpacEnvironmentAcpPolicyAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Assigns the ACP policy to the environment.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Add-PpacEnvironmentAcpPolicyAssignment {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		if (-not $PSCmdlet.ShouldProcess($EnvironmentId, "Assign ACP policy $PolicyId")) { return }

		$assigned = @(Add-PpacEnvironmentRuleBasedPolicyAssignment -EnvironmentId $EnvironmentId -PolicyId $PolicyId -Confirm:$false)
		if ($assigned.Count -eq 0) { return }
		Get-PpacEnvironmentAcpPolicy -EnvironmentId $EnvironmentId -PolicyId $PolicyId
	}
}
