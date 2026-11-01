<#
    .SYNOPSIS
        Enriches governance rows with assignment state.

    .DESCRIPTION
        Adds Kind, ConnectorManagement, AllowedConnectorCount, AssignmentSource,
        and IsEffective to each governance row.

    .PARAMETER Policy
        Governance policy definitions to enrich.

    .PARAMETER Assignment
        Policy assignments for the selected scope.

        Default: @()

    .PARAMETER Scope
        Tenant, Environment, or EnvironmentGroup.

    .EXAMPLE
        PS C:\> Get-BapGovernancePolicyView -Policy $policies -Assignment @() -Scope Tenant

        Enriches tenant policy definitions.
        It uses -Policy to pass the definitions.
        It uses -Assignment to pass the assignments.
        It uses -Scope to select tenant scope.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-BapGovernancePolicyView {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[object[]] $Policy,
		[object[]] $Assignment = @(),

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Tenant', 'Environment', 'EnvironmentGroup')]
		[string] $Scope
	)

	foreach ($item in $Policy) {
		$tmpRuleSets = @($item.ruleSets)
		$tmpConnectorManagement = @($tmpRuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1
		$kind = if ($null -ne $tmpConnectorManagement) { 'Acp' } else { 'Other' }
		$allowedConnectorCount = if ($null -ne $tmpConnectorManagement) { @($tmpConnectorManagement.inputs.AllowedConnectorList).Count } else { 0 }

		$policyId = "$($item.id)"
		$tmpMatchingAssignment = @($Assignment | Where-Object {
				$assignmentPolicyId = if (-not [string]::IsNullOrWhiteSpace("$($_.policyId)")) { "$($_.policyId)" } else { "$($_.PolicyId)" }
				$assignmentPolicyId -eq $policyId
			}) | Select-Object -First 1

		$assignmentSource = switch ($Scope) {
			'Tenant' { 'Definition' }
			'Environment' {
				if ($null -eq $tmpMatchingAssignment) { 'None' }
				elseif ("$($tmpMatchingAssignment.resourceType)" -eq 'EnvironmentGroup' -or "$($tmpMatchingAssignment.ResourceType)" -eq 'EnvironmentGroup') { 'Inherited' }
				else { 'Direct' }
			}
			'EnvironmentGroup' {
				if ($null -eq $tmpMatchingAssignment) { 'None' } else { 'Direct' }
			}
		}

		$isEffective = if ($Scope -eq 'Tenant') { $true } else { $null -ne $tmpMatchingAssignment }

		$item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'ConnectorManagement'; Expression = { $tmpConnectorManagement } }, @{ Name = 'AllowedConnectorCount'; Expression = { $allowedConnectorCount } }, @{ Name = 'AssignmentSource'; Expression = { $assignmentSource } }, @{ Name = 'IsEffective'; Expression = { $isEffective } }
	}
}
