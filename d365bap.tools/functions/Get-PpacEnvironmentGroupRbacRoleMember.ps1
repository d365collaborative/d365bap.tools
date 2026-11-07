<#
    .SYNOPSIS
        List environment group RBAC assignments.

    .DESCRIPTION
        Returns Power Platform RBAC assignments that apply inside one group scope.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER ServicePrincipalId
        Service principal filter. Wildcards are accepted.

        Default: *

    .PARAMETER Role
        Assignment name, id, or wildcard filter.

        Default: *

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId "00000000-0000-0000-0000-000000000000"

        Lists group assignments.
        It uses -EnvironmentGroupId to select the group.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -Role "*admin*"

        Lists filtered group assignments.
        It uses -EnvironmentGroupId to select the group.
        It uses -Role to filter assignments.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports group assignments.
        It uses -EnvironmentGroupId to select the group.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Get-PpacEnvironmentGroupRbacRoleMember {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment[]', [object[]])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $ServicePrincipalId = '*',

		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $Role = '*',

		[switch] $AsExcelOutput
	)

	process {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			'Content-Type' = 'application/json'
			Authorization  = "Bearer $tokenValue"
		}

		$colRbacRoles = @(Get-BapRbacRoleCatalog)

		$hashRoleNames = @{}
		foreach ($itemRole in $colRbacRoles) {
			$hashRoleNames[$itemRole.roleDefinitionId] = $itemRole.roleDefinitionName
		}

		$colMatchingIds = @(
			$colRbacRoles |
			Where-Object {
				($_.roleDefinitionName -like $Role) `
					-or ($_.roleDefinitionId -like $Role)
			} | Select-Object -ExpandProperty roleDefinitionId
		)

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uri = 'https://api.powerplatform.com/authorization/environmentGroups/{0}/roleAssignments?api-version={1}' `
			-f $EnvironmentGroupId,
		$apiVersion

		try {
			$objResponse = Invoke-RestMethod -Method Get `
				-Uri $uri `
				-Headers $hashHeaders `
				-ErrorAction Stop
		}
		catch {
			$messageString = "Failed to retrieve group RBAC assignments for <c='em'>$EnvironmentGroupId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because the group RBAC request failed.' `
				-Exception $_.Exception

			return
		}

		$colRaw = @($objResponse.value)

		$colFiltered = @(
			$colRaw |
			Where-Object {
				($_.principalObjectId -like $ServicePrincipalId) `
					-and ($_.roleDefinitionId -in $colMatchingIds)
			}
		)

		$colRes = @(
			$colFiltered |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacRbacRoleAssignment' `
				-ExcludeProperty '@odata.etag' `
				-Property 'principalObjectId as ServicePrincipalId',
			'roleDefinitionId as RoleId',
			@{ Name = 'Role'; Expression = { $hashRoleNames[$_.roleDefinitionId] } },
			@{ Name = 'EnvironmentGroupId'; Expression = { $EnvironmentGroupId } },
			*
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentGroupRbacRoleMember' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
