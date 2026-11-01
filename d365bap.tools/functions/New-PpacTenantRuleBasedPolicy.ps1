<#
    .SYNOPSIS
        Create a tenant governance rule-based policy.

    .DESCRIPTION
        Creates a governance rule-based policy definition through the Power
        Platform API.

        The rule set objects are passed through to the service.

    .PARAMETER Name
        The display name of the new policy.

    .PARAMETER RuleSet
        One or more rule set objects with id, version, and inputs.

    .EXAMPLE
        PS C:\> New-PpacTenantRuleBasedPolicy -Name "Sharing baseline" -RuleSet @(@{ id = "Sharing"; version = "1.0"; inputs = @{} })

        Creates a policy with a Sharing rule set.
        It uses -Name to name the policy.
        It uses -RuleSet to supply the rule set definitions.

    .NOTES
        Author: d365bap.tools contributors
#>
function New-PpacTenantRuleBasedPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[object[]] $RuleSet
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$body = [ordered]@{
			name     = $Name
			ruleSets = @($RuleSet)
		} | ConvertTo-Json -Depth 20

		$shouldAffected = $Name
		$shouldLabel = 'Create governance rule-based policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$secureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$uri = "https://api.powerplatform.com/governance/ruleBasedPolicies?api-version=$apiVersion"

		try {
			$created = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
				Authorization = "Bearer $tokenValue"
				Accept        = 'application/json'
			} -Body $body -ContentType 'application/json' -ErrorAction Stop
		}
		catch {
			$messageString = "Failed to create governance policy <c='em'>$Name</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance policy create request failed." -Exception $_.Exception
			return
		}

		if (-not [string]::IsNullOrWhiteSpace("$($created.id)")) {
			Get-PpacTenantRuleBasedPolicy -PolicyId $created.id
		}
	}
}
