<#
    .SYNOPSIS
        List classic DLP policies for an environment.

    .DESCRIPTION
        Retrieves classic DLP policies visible to an environment, including
        inherited tenant policies.

        IsEffective shows whether a policy applies to the environment.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter.

        Default: *

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the DLP policies for the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "*restrict*"

        Lists policies that match the filter, effective or not.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to filter on policy id or display name.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns a policy by GUID or display name, effective or not.
        It uses -EnvironmentId to select the environment.
        It uses -PolicyId to select the policy.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports effective DLP policies to an Excel workbook.
        It uses -EnvironmentId to select the environment.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentDlpPolicy {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacEnvironmentDlpPolicy[]', [object[]])]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $PolicyId = '*',

		[switch] $AsExcelOutput
	)

	process {
		$objEnvironment = Resolve-PpacResourceEnvironment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$routeEnvironmentId = $objEnvironment.PpacEnvId
		$routeEnvironmentName = $objEnvironment.PpacEnvName

		$candidateIds = @(
			$routeEnvironmentId
			$objEnvironment.EnvId
			$objEnvironment.PpacEnvId
			$objEnvironment.PpacEnvName
			if ($routeEnvironmentId -like 'Default-*') {
				$routeEnvironmentId.Substring(8)
			}
		) |
		Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
		ForEach-Object { "$_".ToLowerInvariant() } |
		Select-Object -Unique

		try {
			$colPolicies = @(Get-BapDlpPolicy)
		}
		catch {
			$messageString = "Failed to retrieve DLP policies for environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the DLP policy request failed." `
				-Exception $_.Exception

			return
		}

		$colPolicies = @(
			foreach ($itemPolicy in $colPolicies) {
				$tmpPolicyIds = @(
					$itemPolicy.environments.id |
					ForEach-Object { "$_".ToLowerInvariant() })
				$matchesEnvironment = @(
					$candidateIds |
					Where-Object { $_ -in $tmpPolicyIds }).Count -gt 0

				$isEffective = switch ("$($itemPolicy.environmentType)") {
					'AllEnvironments' { $true }
					'OnlyEnvironments' { $matchesEnvironment }
					'ExceptEnvironments' { -not $matchesEnvironment }
					'SingleEnvironment' { $matchesEnvironment }
					Default { $false }
				}

				$tmpConnectorCount = (@($itemPolicy.connectorGroups) |
					ForEach-Object { @($_.connectors).Count } |
					Measure-Object -Sum).Sum
				$tmpEnvironmentNames = @($itemPolicy.environments.name) |
				Where-Object { $_ } |
				Sort-Object -Unique

				$itemPolicy |
				Select-Object -Property *,
				@{ Name = 'IsEffective'; Expression = { $isEffective } },
				@{ Name = 'IsInherited'; Expression = { $_.environmentType -ne 'SingleEnvironment' } },
				@{ Name = 'ConnectorCount'; Expression = { $tmpConnectorCount } },
				@{ Name = 'EnvironmentNames'; Expression = { $tmpEnvironmentNames -join ', ' } }
			}
		)

		$colPolicies = @(
			$colPolicies |
			Where-Object {
				($_.name -like $PolicyId) `
					-or ($_.displayName -like $PolicyId)
			})

		$colPolicies = @(
			$colPolicies |
			Sort-Object -Property @{ Expression = { -not $_.IsEffective } },
			@{ Expression = { $_.displayName } },
			@{ Expression = { $_.name } })

		$colRes = @(
			$colPolicies |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentDlpPolicy' `
				-Property `
				'name as PolicyId',
			'displayName as Name',
			@{ Name = 'PolicyScope'; Expression = { if ($_.environmentType -eq 'SingleEnvironment') { 'Environment' } else { 'Tenant' } } },
			'IsInherited as IsInherited',
			'IsEffective as IsEffective',
			'environmentType as EnvironmentType',
			'defaultConnectorsClassification as DefaultConnectorClassification',
			@{ Name = 'ConnectorGroupCount'; Expression = { @($_.connectorGroups).Count } },
			'ConnectorCount as ConnectorCount',
			@{ Name = 'EnvironmentCount'; Expression = { @($_.environments).Count } },
			@{ Name = 'EnvironmentIds'; Expression = { @($_.environments.id) -join ', ' } },
			'EnvironmentNames as EnvironmentNames',
			@{ Name = 'CreatedBy'; Expression = { if (-not [string]::IsNullOrWhiteSpace($_.createdBy.displayName)) { $_.createdBy.displayName } else { $_.createdBy.userPrincipalName } } },
			'createdTime as CreatedTime',
			@{ Name = 'LastModifiedBy'; Expression = { if (-not [string]::IsNullOrWhiteSpace($_.lastModifiedBy.displayName)) { $_.lastModifiedBy.displayName } else { $_.lastModifiedBy.userPrincipalName } } },
			'lastModifiedTime as LastModifiedTime',
			'isLegacySchemaVersion as IsLegacySchemaVersion',
			'connectorGroups as ConnectorGroups',
			@{ Name = 'PpacEnvId'; Expression = { $routeEnvironmentId } },
			@{ Name = 'PpacEnvName'; Expression = { $routeEnvironmentName } }
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentDlpPolicy' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
