<#
    .SYNOPSIS
        List governance policies assigned to an environment group.

    .DESCRIPTION
        Retrieves the governance rule-based policy assigned to an environment
        group through the Power Platform API.

        Only advanced connector policies are returned when the ACP view is
        requested.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter. Includes unassigned policies.

        Default: *

    .PARAMETER Kind
        All returns every rule-based policy. Acp returns ACP policies only.

        Default: All

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000"

        Lists the policy assigned to the group.
        It uses -EnvironmentGroupId to select the group.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -Kind Acp

        Lists the advanced connector policy assigned to the group.
        It uses -EnvironmentGroupId to select the group.
        It uses -Kind to select the policy kind.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns a policy by GUID or display name, assigned or not.
        It uses -EnvironmentGroupId to select the group.
        It uses -PolicyId to select the policy.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports group policies to an Excel workbook.
        It uses -EnvironmentGroupId to select the group.
        It uses -AsExcelOutput to write an Excel file.
        It uses -Kind All by default.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentGroupRuleBasedPolicy {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[ValidateSet('All', 'Acp')]
		[string] $Kind = 'All',

		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		try {
			$colPolicies = @(Get-BapGovernancePolicy)
			$colAssignments = @(Get-BapGovernancePolicyAssignment -EnvironmentGroupId $EnvironmentGroupId)
			$colPolicies = @(Get-BapGovernancePolicyView -Policy $colPolicies -Assignment $colAssignments -Scope EnvironmentGroup)
		}
		catch {
			$messageString = "Failed to retrieve governance policies for environment group <c='em'>$EnvironmentGroupId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance policy request failed." -Exception $_.Exception
			return
		}

		if ($Kind -eq 'Acp') { $colPolicies = @($colPolicies | Where-Object Kind -eq 'Acp') }

		if ($PolicyId -ne '*') {
			$colPolicies = @($colPolicies | Where-Object {
					$_.id -like $PolicyId -or $_.name -like $PolicyId
				})
		}
		else {
			$colPolicies = @($colPolicies | Where-Object IsEffective)
		}

		$colPolicies = @($colPolicies | Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, @{ Expression = { $_.name } }, @{ Expression = { $_.id } })

		$colRes = @(
			$colPolicies | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentGroupRuleBasedPolicy' -Property `
				'id as PolicyId',
			'name as Name',
			'Kind as Kind',
			'lastModified as LastModified',
			@{ Name = 'RuleSetCount'; Expression = { if ($null -ne $_.ruleSetCount) { $_.ruleSetCount } else { @($_.ruleSets).Count } } },
			@{ Name = 'RuleSetIds'; Expression = { @($_.ruleSets.id | Where-Object { $_ }) -join ', ' } },
			'AssignmentSource as AssignmentSource',
			'IsEffective as IsEffective',
			'tenantId as TenantId',
			'AllowedConnectorCount as AllowedConnectorCount',
			'ruleSets as RuleSets',
			@{ Name = 'EnvironmentGroupId'; Expression = { $EnvironmentGroupId } }
		)

		if ($AsExcelOutput) {
			if ($colRes.Count -gt 0) {
				$colRes | Export-Excel -WorksheetName 'Get-PpacEnvironmentGroupRuleBasedPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$colRes
	}
}
