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
	[OutputType('D365Bap.Tools.PpacTenantAcpPolicy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $ConnectorId
	)

	process {
		$colAllowed = foreach ($itemConnector in $ConnectorId) {
			$fullId = if ($itemConnector -like '/providers/*') { $itemConnector } else { "/providers/Microsoft.PowerApps/apis/$itemConnector" }
			[ordered]@{
				AllowedConnector           = $fullId
				AllowedActionsMode         = 'AllAllowed'
				AllowedConnectionTypesMode = 'AllAllowed'
			}
		}

		$colRuleSet = @(
			[ordered]@{
				id      = 'ConnectorManagement'
				version = '1.0'
				inputs  = [ordered]@{ AllowedConnectorList = @($colAllowed) }
			}
		)

		$shouldAffected = $Name
		$shouldLabel = 'Create advanced connector policy'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$colCreated = @(New-PpacTenantRuleBasedPolicy -Name $Name `
				-RuleSet $colRuleSet `
				-Confirm:$false)
		if ($colCreated.Count -eq 0) { return }
		Get-PpacTenantAcpPolicy -PolicyId $colCreated[0].PolicyId
	}
}
