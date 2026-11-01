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
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,
		[ValidateNotNullOrEmpty()]
		[string] $Name,
		[ValidateNotNullOrEmpty()]
		[string[]] $ConnectorId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		if (-not $PSBoundParameters.ContainsKey('Name') -and -not $PSBoundParameters.ContainsKey('ConnectorId')) {
			Stop-PSFFunction -Message "Specify -Name, -ConnectorId, or both."
			return
		}

		$current = @(Get-PpacTenantAcpPolicy -PolicyId $PolicyId)
		if ($current.Count -eq 0) {
			Stop-PSFFunction -Message "No ACP policy matched '$PolicyId'."
			return
		}
		if ($current.Count -gt 1) {
			Stop-PSFFunction -Message "Multiple ACP policies matched '$PolicyId'. Use a policy GUID."
			return
		}

		$ruleSet = @($current[0].RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1
		if ($null -eq $ruleSet) {
			Stop-PSFFunction -Message "Policy '$PolicyId' has no ConnectorManagement rule set."
			return
		}

		if ($PSBoundParameters.ContainsKey('ConnectorId')) {
			$allowed = foreach ($connector in $ConnectorId) {
				$fullId = if ($connector -like '/providers/*') { $connector } else { "/providers/Microsoft.PowerApps/apis/$connector" }
				[ordered]@{
					AllowedConnector           = $fullId
					AllowedActionsMode         = 'AllAllowed'
					AllowedConnectionTypesMode = 'AllAllowed'
				}
			}

			$ruleSet = [ordered]@{
				id      = 'ConnectorManagement'
				version = if ([string]::IsNullOrWhiteSpace("$($ruleSet.version)")) { '1.0' } else { $ruleSet.version }
				inputs  = [ordered]@{ AllowedConnectorList = @($allowed) }
			}
		}

		if (-not $PSCmdlet.ShouldProcess($PolicyId, 'Update advanced connector policy')) { return }

		$params = @{
			PolicyId = $current[0].PolicyId
			RuleSet  = @($ruleSet)
		}
		if ($PSBoundParameters.ContainsKey('Name')) { $params.Name = $Name }

		$null = Set-PpacTenantRuleBasedPolicy @params -Confirm:$false
		Get-PpacTenantAcpPolicy -PolicyId $current[0].PolicyId
	}
}
