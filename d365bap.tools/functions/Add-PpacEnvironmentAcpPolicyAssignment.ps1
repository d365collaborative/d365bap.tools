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
	[OutputType('D365Bap.Tools.PpacEnvironmentAcpPolicy')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		$colPolicy = @(Get-PpacTenantAcpPolicy -PolicyId $PolicyId)
		if ($colPolicy.Count -eq 0) {
			Stop-PSFFunction -Message "No ACP policy matched '$PolicyId'."
			return
		}
		if ($colPolicy.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple ACP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colPolicy[0].Name
		if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = $colPolicy[0].PolicyId }

		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1
		$environmentLabel = $envObj.PpacEnvName

		$shouldAffected = $policyName
		$shouldLabel = "Assign ACP policy to '$environmentLabel'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$colAssigned = @(Add-PpacEnvironmentRuleBasedPolicyAssignment -EnvironmentId $EnvironmentId `
				-PolicyId $colPolicy[0].PolicyId `
				-Confirm:$false)

		if ($colAssigned.Count -eq 0) { return }

		Get-PpacEnvironmentAcpPolicy -EnvironmentId $EnvironmentId `
			-PolicyId $colPolicy[0].PolicyId
	}
}
