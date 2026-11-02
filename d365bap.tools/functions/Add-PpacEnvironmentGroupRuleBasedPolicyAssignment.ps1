<#
    .SYNOPSIS
        Assign a governance policy to an environment group.

    .DESCRIPTION
        Creates a governance rule-based policy assignment for an environment
        group through the Power Platform API.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .EXAMPLE
        PS C:\> Add-PpacEnvironmentGroupRuleBasedPolicyAssignment -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Assigns the policy to the group.
        It uses -EnvironmentGroupId to select the group.
        It uses -PolicyId to select the policy.

    .NOTES
        Author: d365bap.tools contributors
#>
function Add-PpacEnvironmentGroupRuleBasedPolicyAssignment {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacEnvironmentGroupRuleBasedPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId
	)

	process {
		$groupLabel = $EnvironmentGroupId
		try {
			$objGroup = Get-PpacEnvironmentGroup -EnvironmentGroup $EnvironmentGroupId | Select-Object -First 1
			if (-Not ($null -eq $objGroup) -and -not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)")) {
				$groupLabel = $objGroup.DisplayName
			}
		}
		catch {
			$groupLabel = $EnvironmentGroupId
		}

		$colPolicy = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($colPolicy.Count -eq 0) {
			Stop-PSFFunction -Message "No governance policy matched '$PolicyId'."
			return
		}
		if ($colPolicy.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple governance policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colPolicy[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colPolicy[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = "Assign policy to group '$groupLabel'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken
		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uri = 'https://api.powerplatform.com/governance/ruleBasedPolicies/{0}/environmentGroups/{1}/assignments?api-version={2}' `
			-f $colPolicy[0].PolicyId,
		$EnvironmentGroupId,
		$apiVersion

		try {
			$null = Invoke-RestMethod -Method Post `
				-Uri $uri `
				-Headers @{
				Authorization = "Bearer $tokenValue"
				Accept        = 'application/json'
			} `
				-Body '{}' `
				-ContentType 'application/json' `
				-ErrorAction Stop
		}
		catch {
			$messageString = "Failed to assign governance policy <c='em'>$PolicyId</c> to environment group <c='em'>$EnvironmentGroupId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance assignment request failed." `
				-Exception $_.Exception
			return
		}

		Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId $EnvironmentGroupId `
			-PolicyId $colPolicy[0].PolicyId
	}
}
