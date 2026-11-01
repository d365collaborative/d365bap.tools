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
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $RuleSetId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$current = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($current.Count -eq 0) {
			Stop-PSFFunction -Message "No governance policy matched '$PolicyId'."
			return
		}
		if ($current.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple governance policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		if (-not $PSCmdlet.ShouldProcess($current[0].PolicyId, "Remove rule set $RuleSetId")) { return }

		$body = [ordered]@{
			name     = $current[0].Name
			ruleSets = @([ordered]@{ id = $RuleSetId })
		} | ConvertTo-Json -Depth 20

		$secureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/$($current[0].PolicyId)/removeRule?api-version=$apiVersion"

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

		Get-PpacTenantRuleBasedPolicy -PolicyId $current[0].PolicyId
	}
}
