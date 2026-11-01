<#
    .SYNOPSIS
        List tenant governance rule-based policies.

    .DESCRIPTION
        Retrieves every governance rule-based policy definition in the tenant
        through the Power Platform API.

        Only advanced connector policies are returned when the ACP view is
        requested.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter.

        Default: *

    .PARAMETER Kind
        All returns every rule-based policy. Acp returns ACP policies only.

        Default: All

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacTenantRuleBasedPolicy

        Lists every governance rule-based policy.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacTenantRuleBasedPolicy -Kind Acp

        Lists only advanced connector policies.
        It uses -Kind to select the policy kind.

    .EXAMPLE
        PS C:\> Get-PpacTenantRuleBasedPolicy -PolicyId "*baseline*"

        Lists policies that match the name filter.
        It uses -PolicyId to filter on policy id or display name.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacTenantRuleBasedPolicy -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns one policy by GUID or display name.
        It uses -PolicyId to select the policy.
        It uses -Kind All by default.

    .EXAMPLE
        PS C:\> Get-PpacTenantRuleBasedPolicy -AsExcelOutput

        Exports tenant rule-based policies to an Excel workbook.
        It uses -AsExcelOutput to write an Excel file.
        It uses -Kind All by default.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacTenantRuleBasedPolicy {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacTenantRuleBasedPolicy[]', [object[]])]
	param (
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[ValidateSet('All', 'Acp')]
		[string] $Kind = 'All',

		[switch] $AsExcelOutput
	)

	process {
		try {
			$colPolicies = @(Get-BapGovernancePolicyView -Policy @(Get-BapGovernancePolicy) -Assignment @() -Scope Tenant)
		}
		catch {
			$messageString = "Failed to retrieve governance rule-based policies. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance policy request failed." -Exception $_.Exception
			return
		}

		if ($Kind -eq 'Acp') { $colPolicies = @($colPolicies | Where-Object Kind -eq 'Acp') }

		$colPolicies = @($colPolicies | Where-Object {
				$_.id -like $PolicyId -or $_.name -like $PolicyId
			})

		$colPolicies = @($colPolicies | Sort-Object -Property name, id)

		$colRes = @(
			$colPolicies | Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantRuleBasedPolicy' -Property `
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
			'ruleSets as RuleSets'
		)

		if ($AsExcelOutput) {
			if ($colRes.Count -gt 0) {
				$colRes | Export-Excel -WorksheetName 'Get-PpacTenantRuleBasedPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$colRes
	}
}
