<#
    .SYNOPSIS
        List effective classic DLP policies for an environment.

    .DESCRIPTION
        Retrieves classic DLP policies that apply to an environment,
        including inherited tenant policies.

        A policy requested directly is returned even when it does not apply,
        with IsEffective set to false.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER PolicyId
        Policy GUID, display name, or wildcard filter. Includes non-effective policies.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentDlpPolicy -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the DLP policies that apply to the environment.
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
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $PolicyId,

		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$envObj = Get-Environment `
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
			$messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-Environment</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		$candidateIds = @(
			$routeEnvironmentId
			if ($null -ne $envObj) {
				$envObj.EnvId
				$envObj.PpacEnvId
				$envObj.PpacEnvName
			}
			if ($routeEnvironmentId -like 'Default-*') {
				$routeEnvironmentId.Substring(8)
			}
		) | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") } | ForEach-Object { "$_".ToLowerInvariant() } | Select-Object -Unique

		try {
			$policies = @(Get-BapDlpPolicy)
		}
		catch {
			$messageString = "Failed to retrieve DLP policies for environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the DLP policy request failed." -Exception $_.Exception
			return
		}

		$policies = @(
			foreach ($policy in $policies) {
				$policyIds = @($policy.environments.id | ForEach-Object { "$_".ToLowerInvariant() })
				$matchesEnvironment = @($candidateIds | Where-Object { $_ -in $policyIds }).Count -gt 0

				$isEffective = switch ("$($policy.environmentType)") {
					'AllEnvironments' { $true }
					'OnlyEnvironments' { $matchesEnvironment }
					'ExceptEnvironments' { -not $matchesEnvironment }
					'SingleEnvironment' { $matchesEnvironment }
					Default { $false }
				}

				$policy | Select-Object *, @{ Name = 'IsEffective'; Expression = { $isEffective } }, @{ Name = 'IsInherited'; Expression = { $_.environmentType -ne 'SingleEnvironment' } }
			}
		)

		if ($PSBoundParameters.ContainsKey('PolicyId')) {
			$policies = @($policies | Where-Object {
					$_.name -like $PolicyId -or $_.displayName -like $PolicyId
				})
		}
		else {
			$policies = @($policies | Where-Object { $_.IsEffective })
		}

		$policies = @($policies | Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, @{ Expression = { $_.displayName } }, @{ Expression = { $_.name } })

		$resCol = @(
			$policies | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentDlpPolicy' -Property `
				'name as PolicyId',
			'displayName as Name',
			@{ Name = 'PolicyScope'; Expression = { if ($_.environmentType -eq 'SingleEnvironment') { 'Environment' } else { 'Tenant' } } },
			'IsInherited as IsInherited',
			'IsEffective as IsEffective',
			'environmentType as EnvironmentType',
			'defaultConnectorsClassification as DefaultConnectorClassification',
			@{ Name = 'ConnectorGroupCount'; Expression = { @($_.connectorGroups).Count } },
			@{ Name = 'ConnectorCount'; Expression = { (@($_.connectorGroups) | ForEach-Object { @($_.connectors).Count } | Measure-Object -Sum).Sum } },
			@{ Name = 'EnvironmentCount'; Expression = { @($_.environments).Count } },
			@{ Name = 'EnvironmentIds'; Expression = { @($_.environments.id) -join ', ' } },
			@{ Name = 'EnvironmentNames'; Expression = { @($_.environments.name | Where-Object { $_ } | Sort-Object -Unique) -join ', ' } },
			@{ Name = 'CreatedBy'; Expression = { if (-not [string]::IsNullOrWhiteSpace("$($_.createdBy.displayName)")) { $_.createdBy.displayName } else { $_.createdBy.userPrincipalName } } },
			'createdTime as CreatedTime',
			@{ Name = 'LastModifiedBy'; Expression = { if (-not [string]::IsNullOrWhiteSpace("$($_.lastModifiedBy.displayName)")) { $_.lastModifiedBy.displayName } else { $_.lastModifiedBy.userPrincipalName } } },
			'lastModifiedTime as LastModifiedTime',
			'isLegacySchemaVersion as IsLegacySchemaVersion',
			'connectorGroups as ConnectorGroups',
			@{ Name = 'PpacEnvId'; Expression = { $routeEnvironmentId } },
			@{ Name = 'PpacEnvName'; Expression = { $routeEnvironmentName } }
		)

		if ($AsExcelOutput) {
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacEnvironmentDlpPolicy' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
