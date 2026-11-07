<#
    .SYNOPSIS
        Add an environment group RBAC member.

    .DESCRIPTION
        Creates a Power Platform RBAC assignment inside one group and returns the new membership.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER ServicePrincipalId
        The object id of the service principal for the new member.

    .PARAMETER Role
        The RBAC name or id for the new assignment.

    .PARAMETER Scope
        The evaluation location for the new assignment.

    .PARAMETER PrincipalType
        The principal kind for the new member.

        Default: ApplicationUser

    .EXAMPLE
        PS C:\> Add-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -ServicePrincipalId "11111111-1111-1111-1111-111111111111" -Role "Power Platform Administrator" -Scope "/tenants/22222222-2222-2222-2222-222222222222/environmentGroups/00000000-0000-0000-0000-000000000000"

        Assigns a member to the group.
        It uses -EnvironmentGroupId to select the group.
        It uses -ServicePrincipalId to select the member.
        It uses -Role to select the assignment.
        It uses -Scope to set the evaluation location.
        It uses the default -PrincipalType ApplicationUser.

    .EXAMPLE
        PS C:\> Add-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -ServicePrincipalId "11111111-1111-1111-1111-111111111111" -Role "Power Platform Administrator" -Scope "/tenants/22222222-2222-2222-2222-222222222222/environmentGroups/00000000-0000-0000-0000-000000000000" -PrincipalType "ApplicationUser"

        Assigns a member with an explicit kind.
        It uses -EnvironmentGroupId to select the group.
        It uses -ServicePrincipalId to select the member.
        It uses -Role to select the assignment.
        It uses -Scope to set the evaluation location.
        It uses -PrincipalType to set the principal kind.

    .NOTES
        Author: d365bap.tools contributors

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Add-PpacEnvironmentGroupRbacRoleMember {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ServicePrincipalId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Role,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Scope,

		[ValidateNotNullOrEmpty()]
		[string] $PrincipalType = 'ApplicationUser'
	)

	process {

		$colRbacRoles = @(Get-BapRbacRoleCatalog)

		$objMatch = $colRbacRoles |
		Where-Object {
			($_.roleDefinitionName -eq $Role) `
				-or ($_.roleDefinitionId -eq $Role)
		} | Select-Object -First 1

		if ($null -eq $objMatch) {
			$messageString = "The specified role: <c='em'>$Role</c> was not found. Run Get-PpacRbacRole to list valid role names."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message 'Stopping because of invalid role name.' `
				-Exception $([System.Exception]::new(($messageString -replace '<[^>]+>', '')))

			return
		}

		$strRoleDefinitionId = $objMatch.roleDefinitionId

		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			'Content-Type' = 'application/json'
			Authorization  = "Bearer $tokenValue"
		}

		$tenantId = (Get-BapContext).TenantId
		$strScope = $Scope.Replace('/tenants/{0}', "/tenants/$tenantId")

		if ($strScope -like '*{*}*') {
			$messageString = "The specified scope: '$strScope' is not valid. Fill out the missing scope details."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message 'Stopping because of invalid scope.' `
				-Exception $([System.Exception]::new(($messageString -replace '<[^>]+>', '')))

			return
		}

		$roleName = $Role
		$shouldAffected = $roleName
		$shouldLabel = 'Assign group RBAC member'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$body = [ordered]@{
			roleDefinitionId  = $strRoleDefinitionId
			principalObjectId = $ServicePrincipalId
			principalType     = $PrincipalType
			scope             = $strScope
		} | ConvertTo-Json

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uri = 'https://api.powerplatform.com/authorization/environmentGroups/{0}/roleAssignments?api-version={1}' `
			-f $EnvironmentGroupId,
		$apiVersion

		try {
			Invoke-RestMethod -Method Post `
				-Uri $uri `
				-Headers $hashHeaders `
				-Body $body `
				-ContentType 'application/json' `
				-ErrorAction Stop > $null
		}
		catch {
			$messageString = "Failed to assign the role to the service principal. Verify that the service principal exists and the scope is correct. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because assigning the group RBAC member failed.' `
				-Exception $_.Exception

			return
		}

		Get-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId $EnvironmentGroupId `
			-ServicePrincipalId $ServicePrincipalId `
			-Role $Role
	}
}
