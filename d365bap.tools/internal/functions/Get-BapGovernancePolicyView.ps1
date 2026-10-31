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
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[object[]] $Policy,

		[Parameter()]
		[object[]] $Assignment = @(),

		[Parameter(Mandatory = $true)]
		[ValidateSet('Tenant', 'Environment', 'EnvironmentGroup')]
		[string] $Scope
	)

	foreach ($item in $Policy) {
		$ruleSets = @($item.ruleSets)
		$connectorManagement = @($ruleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1
		$kind = if ($null -ne $connectorManagement) { 'Acp' } else { 'Other' }
		$allowedConnectorCount = if ($null -ne $connectorManagement) { @($connectorManagement.inputs.AllowedConnectorList).Count } else { 0 }

		$policyId = "$($item.id)"
		$matchingAssignment = @($Assignment | Where-Object {
				$assignmentPolicyId = if (-not [string]::IsNullOrWhiteSpace("$($_.policyId)")) { "$($_.policyId)" } else { "$($_.PolicyId)" }
				$assignmentPolicyId -eq $policyId
			}) | Select-Object -First 1

		$assignmentSource = switch ($Scope) {
			'Tenant' { 'Definition' }
			'Environment' {
				if ($null -eq $matchingAssignment) { 'None' }
				elseif ("$($matchingAssignment.resourceType)" -eq 'EnvironmentGroup' -or "$($matchingAssignment.ResourceType)" -eq 'EnvironmentGroup') { 'Inherited' }
				else { 'Direct' }
			}
			'EnvironmentGroup' {
				if ($null -eq $matchingAssignment) { 'None' } else { 'Direct' }
			}
		}

		$isEffective = if ($Scope -eq 'Tenant') { $true } else { $null -ne $matchingAssignment }

		$item | Add-Member -NotePropertyName Kind -NotePropertyValue $kind -Force
		$item | Add-Member -NotePropertyName ConnectorManagement -NotePropertyValue $connectorManagement -Force
		$item | Add-Member -NotePropertyName AllowedConnectorCount -NotePropertyValue $allowedConnectorCount -Force
		$item | Add-Member -NotePropertyName AssignmentSource -NotePropertyValue $assignmentSource -Force
		$item | Add-Member -NotePropertyName IsEffective -NotePropertyValue $isEffective -Force

		$item
	}
}
