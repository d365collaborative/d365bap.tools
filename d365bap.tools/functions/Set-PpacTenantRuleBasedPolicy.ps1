<#
    .SYNOPSIS
        Update a tenant governance rule-based policy.

    .DESCRIPTION
        Updates a governance rule-based policy definition through the Power
        Platform API.

        Rule sets are replaced unless a partial update is requested.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .PARAMETER Name
        The new display name for the policy.

    .PARAMETER RuleSet
        Replacement rule set objects with id, version, and inputs.

    .PARAMETER Merge
        Merges the supplied rule sets into the existing policy instead of
        replacing them.

    .EXAMPLE
        PS C:\> Set-PpacTenantRuleBasedPolicy -PolicyId "11111111-1111-1111-1111-111111111111" -Name "Updated baseline"

        Renames the policy.
        It uses -PolicyId to select the policy.
        It uses -Name to set the new display name.

    .EXAMPLE
        PS C:\> Set-PpacTenantRuleBasedPolicy -PolicyId "11111111-1111-1111-1111-111111111111" -RuleSet @(@{ id = "Sharing"; version = "1.0"; inputs = @{} })

        Replaces the policy rule sets.
        It uses -PolicyId to select the policy.
        It uses -RuleSet to replace the rule set definitions.

    .EXAMPLE
        PS C:\> Set-PpacTenantRuleBasedPolicy -PolicyId "11111111-1111-1111-1111-111111111111" -RuleSet @(@{ id = "Sharing"; version = "1.0"; inputs = @{} }) -Merge

        Merges one rule set into the policy.
        It uses -PolicyId to select the policy.
        It uses -RuleSet to supply the rule set definition.
        It uses -Merge to merge instead of replace.

    .NOTES
        Author: d365bap.tools contributors
#>
function Set-PpacTenantRuleBasedPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacTenantRuleBasedPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[PSFValidatePattern('\S', ErrorMessage = 'The name must contain a non-whitespace character.')]
		[string] $Name,

		[ValidateCount(1, [int]::MaxValue)]
		[object[]] $RuleSet,

		[switch] $Merge
	)

	process {
		if ((-not $Name) `
				-and (-not $RuleSet)) {
			Stop-PSFFunction -Message "Specify -Name, -RuleSet, or both."
			return
		}

		$colCurrent = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No tenant policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple tenant policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$payloadName = $Name ? $Name : $colCurrent[0].Name
		$payloadRuleSets = $RuleSet ? @($RuleSet) : @($colCurrent[0].RuleSets)

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = 'Update governance policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$body = [ordered]@{
			name     = $payloadName
			ruleSets = $payloadRuleSets
		} | ConvertTo-Json -Depth 20

		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			Authorization = "Bearer $tokenValue"
			Accept        = 'application/json'
		}

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uri = 'https://api.powerplatform.com/governance/ruleBasedPolicies/{0}?api-version={1}' `
			-f $colCurrent[0].PolicyId,
		$apiVersion

		$method = $Merge ? 'Patch' : 'Put'

		try {
			Invoke-RestMethod -Method $method `
				-Uri $uri `
				-Headers $hashHeaders `
				-Body $body `
				-ContentType 'application/json' `
				-ErrorAction Stop > $null
		}
		catch {
			$messageString = "Failed to update governance policy <c='em'>$PolicyId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the governance policy update request failed." `
				-Exception $_.Exception

			return
		}

		Get-PpacTenantRuleBasedPolicy -PolicyId $colCurrent[0].PolicyId
	}
}
