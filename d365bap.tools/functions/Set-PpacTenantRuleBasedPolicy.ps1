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
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[object[]] $RuleSet,

		[Parameter()]
		[switch] $Merge
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		if (-not $PSBoundParameters.ContainsKey('Name') -and -not $PSBoundParameters.ContainsKey('RuleSet')) {
			Stop-PSFFunction -Message "Specify -Name, -RuleSet, or both."
			return
		}

		$current = @(Get-PpacTenantRuleBasedPolicy -PolicyId $PolicyId)
		if ($current.Count -eq 0) {
			Stop-PSFFunction -Message "No tenant policy matched '$PolicyId'."
			return
		}
		if ($current.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple tenant policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$payloadName = if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { $current[0].Name }
		$payloadRuleSets = if ($PSBoundParameters.ContainsKey('RuleSet')) { @($RuleSet) } else { @($current[0].RuleSets) }

		if (-not $PSCmdlet.ShouldProcess($current[0].PolicyId, 'Update governance rule-based policy')) { return }

		$body = [ordered]@{
			name     = $payloadName
			ruleSets = $payloadRuleSets
		} | ConvertTo-Json -Depth 20

		$secureToken = Get-BapAccessToken -ResourceUrl 'https://api.powerplatform.com/'
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies/$($current[0].PolicyId)?api-version=$apiVersion"
		$method = if ($Merge) { 'Patch' } else { 'Put' }

		try {
			$null = Invoke-RestMethod -Method $method -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
				Accept        = 'application/json'
			} -Body $body -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to update governance policy <c='em'>$PolicyId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance policy update request failed." -Exception $_.Exception
			return
		}

		Get-PpacTenantRuleBasedPolicy -PolicyId $current[0].PolicyId
	}
}
