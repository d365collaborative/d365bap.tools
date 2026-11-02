<#
    .SYNOPSIS
        List tenant-scoped classic DLP policies.

    .DESCRIPTION
        Retrieves tenant-scoped data loss prevention policies from the
        Business App Platform API.

        Environment-scoped policies are returned by Get-PpacEnvironmentDlpPolicy.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard name filter.

        Default: *

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacTenantDlpPolicy

        Lists every tenant-scoped DLP policy.

    .EXAMPLE
        PS C:\> Get-PpacTenantDlpPolicy -PolicyId "*restrict*"

        Lists tenant policies that match the display name filter.
        It uses -PolicyId to filter on policy id or display name.

    .EXAMPLE
        PS C:\> Get-PpacTenantDlpPolicy -PolicyId "11111111-1111-1111-1111-111111111111"

        Returns one tenant policy by GUID or display name.
        It uses -PolicyId to select the policy.

    .EXAMPLE
        PS C:\> Get-PpacTenantDlpPolicy -AsExcelOutput

        Exports tenant DLP policies to an Excel workbook.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacTenantDlpPolicy {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacTenantDlpPolicy[]', [object[]])]
	param (
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $PolicyId = '*',

		[switch] $AsExcelOutput
	)

	process {
		try {
			$colPolicies = @(
				Get-BapDlpPolicy |
				Where-Object { $_.environmentType -ne 'SingleEnvironment' }
			)
		}
		catch {
			$messageString = "Failed to retrieve tenant DLP policies. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the DLP policy request failed." `
				-Exception $_.Exception

			return
		}

		$colPolicies = @($colPolicies |
			Where-Object {
				($_.name -like $PolicyId) `
					-or ($_.displayName -like $PolicyId)
			})

		$colPolicies = @($colPolicies |
			Sort-Object -Property displayName, name)

		$colPolicies = @(
			foreach ($itemPolicy in $colPolicies) {
				$tmpConnectorCount = (@($itemPolicy.connectorGroups) |
					ForEach-Object { @($_.connectors).Count } |
					Measure-Object -Sum).Sum
				$tmpEnvironmentNames = @($itemPolicy.environments.name) |
				Where-Object { $_ } |
				Sort-Object -Unique

				$itemPolicy |
				Select-Object -Property *,
				@{ Name = 'ConnectorCount'; Expression = { $tmpConnectorCount } },
				@{ Name = 'EnvironmentNames'; Expression = { $tmpEnvironmentNames -join ', ' } }
			}
		)

		$colRes = @(
			$colPolicies |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantDlpPolicy' `
				-Property `
				'name as PolicyId',
			'displayName as Name',
			@{ Name = 'PolicyScope'; Expression = { if ($_.environmentType -eq 'SingleEnvironment') { 'Environment' } else { 'Tenant' } } },
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
			'connectorGroups as ConnectorGroups'
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacTenantDlpPolicy' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
