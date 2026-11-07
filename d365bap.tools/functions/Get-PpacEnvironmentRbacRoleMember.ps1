<#
	.SYNOPSIS
		List environment RBAC assignments.

	.DESCRIPTION
		Retrieves scoped assignments through the Power Platform API with name resolution.

	.PARAMETER EnvironmentId
		Target environment identifier.

	.PARAMETER ServicePrincipalId
		Member object id filter. Wildcards are accepted.

		Default: *

	.PARAMETER Role
		Assignment definition name, id, or wildcard filter.

		Default: *

	.PARAMETER AsExcelOutput
		Exports the results to an Excel workbook.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleMember -EnvironmentId "00000000-0000-0000-0000-000000000000"

		Lists assignments in the environment.
		It uses -EnvironmentId to select the environment.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleMember -EnvironmentId "00000000-0000-0000-0000-000000000000" -Role "*admin*"

		Lists assignments that match the filter.
		It uses -EnvironmentId to select the environment.
		It uses -Role "*admin*" to filter by definition name or id.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleMember -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

		Exports assignments to an Excel workbook.
		It uses -EnvironmentId to select the environment.
		It uses -AsExcelOutput to write an Excel file.

	.NOTES
		Author: d365bap.tools contributors

	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell

	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Get-PpacEnvironmentRbacRoleMember {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $ServicePrincipalId = '*',

		[SupportsWildcards()]
		[string] $Role = '*',

		[switch] $AsExcelOutput
	)

	process {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			'Content-Type' = 'application/json'
		}

		$hashHeaders.Add('Authorization', "Bearer $tokenValue")

		$colDefinitions = @(Get-BapRbacRoleCatalog)

		if ($colDefinitions.Count -eq 0) {
			$apiVersionDefinitions = $script:BapApiVersions.AuthorizationPreview

			$uriDefinitions = 'https://api.powerplatform.com/authorization/roleDefinitions?api-version={0}' `
				-f $apiVersionDefinitions

			try {
				$colDefinitions = @(Invoke-RestMethod -Method Get `
						-Uri $uriDefinitions `
						-Headers $hashHeaders `
						-ErrorAction Stop |
					Select-Object -ExpandProperty value)
			}
			catch {
				$messageString = "Failed to retrieve role definitions for environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
				Write-PSFMessage -Level Important `
					-Message $messageString `
					-Exception $_.Exception

				Stop-PSFFunction -Message 'Stopping because the role definition request failed.' `
					-Exception $_.Exception

				return
			}
		}

		$colMatched = @(
			$colDefinitions |
			Where-Object {
				($_.roleDefinitionName -like $Role) `
					-or ($_.roleDefinitionId -like $Role)
			}
		)

		if ($colMatched.Count -eq 0) {
			$messageString = "The specified role: <c='em'>$Role</c> was not found. Please provide a valid role name. Try running the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message 'Stopping because of invalid role name.' `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colRoleIds = @($colMatched |
			Select-Object -ExpandProperty roleDefinitionId)

		$hashRoleNames = @{}

		foreach ($itemDefinition in $colMatched) {
			$hashRoleNames[$itemDefinition.roleDefinitionId] = $itemDefinition.roleDefinitionName
		}

		$apiVersion = $script:BapApiVersions.PowerPlatform

		$uri = 'https://api.powerplatform.com/authorization/environments/{0}/roleAssignments?api-version={1}' `
			-f $EnvironmentId,
		$apiVersion

		try {
			$colRaw = @(Invoke-RestMethod -Method Get `
					-Uri $uri `
					-Headers $hashHeaders `
					-ErrorAction Stop |
				Select-Object -ExpandProperty value)
		}
		catch {
			$messageString = "Failed to retrieve role assignments for environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because the role assignment request failed.' `
				-Exception $_.Exception

			return
		}

		$colFiltered = @(
			$colRaw |
			Where-Object {
				($_.principalObjectId -like $ServicePrincipalId) `
					-and ($_.roleDefinitionId -in $colRoleIds)
			}
		)

		$colRes = @(
			$colFiltered |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacRbacRoleAssignment' `
				-Property `
				'principalObjectId as ServicePrincipalId',
			'roleDefinitionId as RoleId',
			@{ Name = 'Role'; Expression = { $hashRoleNames[$_.roleDefinitionId] } },
			'principalType as PrincipalType',
			'roleAssignmentId as RoleAssignmentId',
			'scope as Scope'
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentRbacRoleMember' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
