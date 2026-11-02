<#
    .SYNOPSIS
        Update a tenant advanced connector policy.

    .DESCRIPTION
        Updates an advanced connector policy definition through the Power
        Platform API.

        Supplying connectors replaces the existing allowlist.

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches are rejected.

    .PARAMETER Name
        The new display name for the policy.

    .PARAMETER ConnectorId
        Replacement connector short names or full connector resource ids.

    .EXAMPLE
        PS C:\> Set-PpacTenantAcpPolicy -PolicyId "11111111-1111-1111-1111-111111111111" -Name "Updated ACP baseline"

        Renames the ACP policy.
        It uses -PolicyId to select the policy.
        It uses -Name to set the new display name.

    .EXAMPLE
        PS C:\> Set-PpacTenantAcpPolicy -PolicyId "11111111-1111-1111-1111-111111111111" -ConnectorId "shared_office365", "shared_sql"

        Replaces the ACP allowlist.
        It uses -PolicyId to select the policy.
        It uses -ConnectorId to replace the allowed connectors.

    .NOTES
        Author: d365bap.tools contributors
#>
function Set-PpacTenantAcpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacTenantAcpPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,

		[PSFValidatePattern('\S', ErrorMessage = 'The name must contain a non-whitespace character.')]
		[string] $Name,

		[ValidateCount(1, [int]::MaxValue)]
		[string[]] $ConnectorId
	)

	process {
		if (-not $Name -and -not $ConnectorId) {
			Stop-PSFFunction -Message "Specify -Name, -ConnectorId, or both."
			return
		}

		$colCurrent = @(Get-PpacTenantAcpPolicy -PolicyId $PolicyId)
		if ($colCurrent.Count -eq 0) {
			Stop-PSFFunction -Message "No ACP policy matched '$PolicyId'."
			return
		}
		if ($colCurrent.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple ACP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$objRuleSet = @($colCurrent[0].RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1
		if ($null -eq $objRuleSet) {
			Stop-PSFFunction -Message "Policy '$PolicyId' has no ConnectorManagement rule set."
			return
		}

		if ($ConnectorId) {
			$colAllowed = foreach ($itemConnector in $ConnectorId) {
				$fullId = if ($itemConnector -like '/providers/*') { $itemConnector } else { "/providers/Microsoft.PowerApps/apis/$itemConnector" }
				[ordered]@{
					AllowedConnector           = $fullId
					AllowedActionsMode         = 'AllAllowed'
					AllowedConnectionTypesMode = 'AllAllowed'
				}
			}

			$hashRuleSet = [ordered]@{
				id      = 'ConnectorManagement'
				version = if ([string]::IsNullOrWhiteSpace("$($objRuleSet.version)")) { '1.0' } else { $objRuleSet.version }
				inputs  = [ordered]@{ AllowedConnectorList = @($colAllowed) }
			}
		}

		$policyName = $colCurrent[0].Name
		if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colCurrent[0].PolicyId }

		$shouldAffected = $policyName
		$shouldLabel = 'Update advanced connector policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$hashParams = @{
			PolicyId = $colCurrent[0].PolicyId
			RuleSet  = @($hashRuleSet)
		}
		if ($Name) { $hashParams.Name = $Name }

		$null = Set-PpacTenantRuleBasedPolicy @hashParams -Confirm:$false
		Get-PpacTenantAcpPolicy -PolicyId $colCurrent[0].PolicyId
	}
}
