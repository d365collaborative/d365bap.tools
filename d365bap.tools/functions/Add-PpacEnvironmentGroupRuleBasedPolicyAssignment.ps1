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

		$policy = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($policy.Count -eq 0) {
			Stop-PSFFunction -Message "No governance policy matched '$PolicyId'."
			return
		}
		if ($policy.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple governance policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyLabel = $policy[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyLabel")) { $policyLabel = $policy[0].PolicyId }

		if (-not $PSCmdlet.ShouldProcess($policyLabel, "Assign to group '$groupLabel'")) { return }

		$secureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/$($policy[0].PolicyId)/environmentGroups/$EnvironmentGroupId/assignments?api-version=$apiVersion"

		try {
			$null = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
				Accept        = 'application/json'
			} -Body '{}' -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to assign governance policy <c='em'>$PolicyId</c> to environment group <c='em'>$EnvironmentGroupId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance assignment request failed." -Exception $_.Exception
			return
		}

		Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId $EnvironmentGroupId -PolicyId $policy[0].PolicyId
	}
}
