<#
    .SYNOPSIS
        Remove a rule set from a tenant governance policy.

    .DESCRIPTION
        Removes one rule set from a governance rule-based policy definition
        through the Power Platform API.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .PARAMETER RuleSetId
        The rule set id to remove, such as ConnectorManagement.

    .EXAMPLE
        PS C:\> Remove-PpacTenantRuleBasedPolicyRuleSet -PolicyId "11111111-1111-1111-1111-111111111111" -RuleSetId "ConnectorManagement"

        Removes the ConnectorManagement rule set from the policy.
        It uses -PolicyId to select the policy.
        It uses -RuleSetId to select the rule set.

    .NOTES
        Author: d365bap.tools contributors
#>
function Remove-PpacTenantRuleBasedPolicyRuleSet {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacTenantRuleBasedPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $RuleSetId
	)

	process {
		$colCurrent = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No governance policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple governance policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = "Remove policy rule set '$RuleSetId'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$body = [ordered]@{
			name     = $colCurrent[0].Name
			ruleSets = @([ordered]@{ id = $RuleSetId })
		} | ConvertTo-Json -Depth 20

		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $objSecureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/$($colCurrent[0].PolicyId)/removeRule?api-version=$apiVersion"

		try {
			$null = Invoke-RestMethod -Method Patch -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
				Accept        = 'application/json'
			} -Body $body -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to remove rule set <c='em'>$RuleSetId</c> from policy <c='em'>$PolicyId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance rule set removal failed." -Exception $_.Exception
			return
		}

		Get-PpacTenantRuleBasedPolicy -PolicyId $colCurrent[0].PolicyId
	}
}
