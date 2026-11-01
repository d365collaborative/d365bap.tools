<#
    .SYNOPSIS
        Create a tenant advanced connector policy.

    .DESCRIPTION
        Creates an advanced connector policy with a ConnectorManagement rule
        set that allows the supplied connectors.

        Allowed actions and connection types default to AllAllowed.

    .PARAMETER Name
        The display name of the new policy.

    .PARAMETER ConnectorId
        Connector short names or full connector resource ids to allow.

    .EXAMPLE
        PS C:\> New-PpacTenantAcpPolicy -Name "Contoso ACP baseline" -ConnectorId "shared_office365", "shared_sql"

        Creates an ACP policy that allows Office 365 Outlook and SQL Server.
        It uses -Name to name the policy.
        It uses -ConnectorId to list the allowed connectors.

    .NOTES
        Author: d365bap.tools contributors
#>
function New-PpacTenantAcpPolicy {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $ConnectorId
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$allowed = foreach ($connector in $ConnectorId) {
			$fullId = if ($connector -like '/providers/*') { $connector } else { "/providers/Microsoft.PowerApps/apis/$connector" }
			[ordered]@{
				AllowedConnector           = $fullId
				AllowedActionsMode         = 'AllAllowed'
				AllowedConnectionTypesMode = 'AllAllowed'
			}
		}

		$ruleSet = @(
			[ordered]@{
				id      = 'ConnectorManagement'
				version = '1.0'
				inputs  = [ordered]@{ AllowedConnectorList = @($allowed) }
			}
		)

		if (-not $PSCmdlet.ShouldProcess($Name, 'Create advanced connector policy')) { return }

		$created = @(New-PpacTenantRuleBasedPolicy -Name $Name -RuleSet $ruleSet -Confirm:$false)
		if ($created.Count -eq 0) { return }
		Get-PpacTenantAcpPolicy -PolicyId $created[0].PolicyId
	}
}
