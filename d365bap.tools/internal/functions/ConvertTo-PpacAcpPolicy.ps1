<#
    .SYNOPSIS
        Projects governance policies as ACP policy rows.

    .DESCRIPTION
        Converts enriched governance rows into ACP output rows, or into one row
        per allowed connector when expansion is requested.

    .PARAMETER Policy
        Enriched governance policy rows from the general rule-based commands.

    .PARAMETER TypeName
        Output type name for the ACP policy rows.

    .PARAMETER ExpandConnectors
        Returns one row per allowed connector instead of one row per policy.

    .EXAMPLE
        PS C:\> ConvertTo-PpacAcpPolicy -Policy $policies -TypeName "D365Bap.Tools.PpacTenantAcpPolicy"

        Projects the policies as ACP policy rows.
        It uses -Policy to pass the policy rows.
        It uses -TypeName to select the output type.

    .EXAMPLE
        PS C:\> ConvertTo-PpacAcpPolicy -Policy $policies -TypeName "D365Bap.Tools.PpacTenantAcpPolicy" -ExpandConnectors

        Returns one row per allowed connector.
        It uses -Policy to pass the policy rows.
        It uses -TypeName to select the output type.
        It uses -ExpandConnectors to expand the allowlist.

    .NOTES
        Author: d365bap.tools contributors
#>
function ConvertTo-PpacAcpPolicy {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[object[]] $Policy,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $TypeName,

		[Parameter()]
		[switch] $ExpandConnectors
	)

	if ($ExpandConnectors) {
		foreach ($item in $Policy) {
			$connectorManagement = @($item.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1
			foreach ($entry in @($connectorManagement.inputs.AllowedConnectorList)) {
				if ($null -eq $entry) { continue }

				[pscustomobject]@{
					PolicyId                   = $item.PolicyId
					PolicyName                 = $item.Name
					ConnectorId                = $entry.AllowedConnector
					ConnectorName              = if (-not [string]::IsNullOrWhiteSpace("$($entry.AllowedConnector)")) { ($entry.AllowedConnector -split '/')[-1] }
					AllowedActionsMode         = $entry.AllowedActionsMode
					AllowedActions             = @($entry.AllowedActions | Where-Object { $_ }) -join ', '
					AllowedConnectionTypesMode = $entry.AllowedConnectionTypesMode
					AssignmentSource           = $item.AssignmentSource
					IsEffective                = $item.IsEffective
					PpacEnvId                  = $item.PpacEnvId
					PpacEnvName                = $item.PpacEnvName
					EnvironmentGroupId         = $item.EnvironmentGroupId
				} | Select-PSFObject -TypeName 'D365Bap.Tools.PpacAcpConnector' -Property `
					'PolicyId as PolicyId',
				'PolicyName as PolicyName',
				'ConnectorId as ConnectorId',
				'ConnectorName as ConnectorName',
				'AllowedActionsMode as AllowedActionsMode',
				'AllowedActions as AllowedActions',
				'AllowedConnectionTypesMode as AllowedConnectionTypesMode',
				'AssignmentSource as AssignmentSource',
				'IsEffective as IsEffective',
				'PpacEnvId as PpacEnvId',
				'PpacEnvName as PpacEnvName',
				'EnvironmentGroupId as EnvironmentGroupId'
			}
		}
		return
	}

	$Policy | Select-PSFObject -TypeName $TypeName -Property `
		'PolicyId as PolicyId',
	'Name as Name',
	'LastModified as LastModified',
	@{ Name = 'RuleSetVersion'; Expression = { $cm = @($_.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1; if ($null -ne $cm) { $cm.version } } },
	'AllowedConnectorCount as AllowedConnectorCount',
	'AssignmentSource as AssignmentSource',
	'IsEffective as IsEffective',
	'TenantId as TenantId',
	@{ Name = 'AllowedConnectors'; Expression = { $cm = @($_.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1; if ($null -ne $cm) { @($cm.inputs.AllowedConnectorList) } } },
	'PpacEnvId as PpacEnvId',
	'PpacEnvName as PpacEnvName',
	'EnvironmentGroupId as EnvironmentGroupId',
	'RuleSets as RuleSets'
}
