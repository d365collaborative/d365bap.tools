<#
    .SYNOPSIS
        List effective governance policies for an environment.

    .DESCRIPTION
        Retrieves the governance rule-based policies assigned to an environment,
        including policies inherited from its environment group.

        Only advanced connector policies are returned when the ACP view is
        requested.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter. Includes non-effective policies.

        Default: *

    .PARAMETER Kind
        All returns every rule-based policy. Acp returns ACP policies only.

        Default: All

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the policies that apply to the environment.
        It uses -EnvironmentId to select the environment.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -Kind Acp

        Lists only effective advanced connector policies.
        It uses -EnvironmentId to select the environment.
        It uses -Kind to select the policy kind.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns a policy by GUID or display name, effective or not.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports effective policies to an Excel workbook.
        It uses -EnvironmentId to select the environment.
        It uses -AsExcelOutput to write an Excel file.
        It uses -Kind All by default.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentRuleBasedPolicy {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacEnvironmentRuleBasedPolicy[]', [object[]])]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[ValidateSet('All', 'Acp')]
		[string] $Kind = 'All',

		[switch] $AsExcelOutput
	)

	process {
		$envObj = Get-Environment `
			-EnvironmentId $EnvironmentId | `
			Select-Object -First 1

		$routeEnvironmentId = $envObj.PpacEnvId
		$routeEnvironmentName = $envObj.PpacEnvName

		if (Test-PSFFunctionInterrupt) { return }

		try {
			$colPolicies = @(Get-BapGovernancePolicy)
			$colAssignments = @(Get-BapGovernancePolicyAssignment -EnvironmentId $routeEnvironmentId)
			$colPolicies = @(Get-BapGovernancePolicyView -Policy $colPolicies -Assignment $colAssignments -Scope Environment)
		}
		catch {
			$messageString = "Failed to retrieve governance policies for environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
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
			$colPolicies | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentRuleBasedPolicy' -Property `
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
			@{ Name = 'PpacEnvId'; Expression = { $routeEnvironmentId } },
			@{ Name = 'PpacEnvName'; Expression = { $routeEnvironmentName } }
		)

		if ($AsExcelOutput) {
			if ($colRes.Count -gt 0) {
				$colRes | Export-Excel -WorksheetName 'Get-PpacEnvironmentRuleBasedPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$colRes
	}
}
