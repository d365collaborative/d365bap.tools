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

    .PARAMETER Name
        Policy id or display name filter. Wildcards are accepted.

        Default: *

    .PARAMETER Kind
        All returns every rule-based policy. Acp returns ACP policies only.

        Default: All

    .PARAMETER PolicyId
        Policy GUID or display name. Multiple name matches return all matches.

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
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $Name = '*',
		[ValidateSet('All', 'Acp')]
		[string] $Kind = 'All',

		[ValidateNotNullOrEmpty()]
		[string] $PolicyId,
		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$envObj = Get-BapEnvironment `
			-EnvironmentId $EnvironmentId | `
			Select-Object -First 1

		if ($null -ne $envObj) {
			$routeEnvironmentId = $envObj.PpacEnvId
			$routeEnvironmentName = $envObj.PpacEnvName
		}
		else {
			$routeEnvironmentId = $null
			$routeEnvironmentName = $EnvironmentId

			if ($EnvironmentId -match '^Default-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
				$routeEnvironmentId = $EnvironmentId
			}
			else {
				$environmentGuid = [guid]::Empty
				if ([guid]::TryParse($EnvironmentId, [ref]$environmentGuid)) {
					$tenantId = $null
					try {
						$tenantId = (Get-BapContext).TenantId
					}
					catch {
						$tenantId = $null
					}

					if (-not [string]::IsNullOrWhiteSpace("$tenantId") -and $environmentGuid -eq [guid]$tenantId) {
						$routeEnvironmentId = "Default-$tenantId"
					}
					else {
						$routeEnvironmentId = "$environmentGuid"
					}
				}
			}
		}

		if ([string]::IsNullOrWhiteSpace("$routeEnvironmentId")) {
			$messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		try {
			$policies = @(Get-BapGovernancePolicy)
			$assignments = @(Get-BapGovernancePolicyAssignment -EnvironmentId $routeEnvironmentId)
			$policies = @(Get-BapGovernancePolicyView -Policy $policies -Assignment $assignments -Scope Environment)
		}
		catch {
			$messageString = "Failed to retrieve governance policies for environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the governance policy request failed." -Exception $_.Exception
			return
		}

		if ($Kind -eq 'Acp') { $policies = @($policies | Where-Object Kind -eq 'Acp') }

		if ($PSBoundParameters.ContainsKey('PolicyId') -and $PSBoundParameters.ContainsKey('Name')) {
			Stop-PSFFunction -Message "Specify -Name or -PolicyId, not both."
			return
		}

		if ($PSBoundParameters.ContainsKey('PolicyId')) {
			$policies = @($policies | Where-Object {
					$_.id -eq $PolicyId -or $_.name -eq $PolicyId
				})
		}
		else {
			$policies = @($policies | Where-Object {
					$_.IsEffective `
						-and ($_.id -like $Name -or $_.id -eq $Name `
							-or $_.name -like $Name -or $_.name -eq $Name)
				})
		}

		$policies = @($policies | Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, @{ Expression = { $_.name } }, @{ Expression = { $_.id } })

		$resCol = @(
			$policies | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentRuleBasedPolicy' -Property `
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
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacEnvironmentRuleBasedPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
