
<#
    .SYNOPSIS
        Add a service principal as a member of a PPAC RBAC role in a specific scope.

    .DESCRIPTION
        Creates a Power Platform authorization assignment for a principal and returns the current membership.

        The assignment is created in the tenant root while evaluation uses the supplied target.

    .PARAMETER ServicePrincipalId
        The object id of the service principal to which the role will be assigned.

    .PARAMETER Role
        Assignment target name or id. Use Get-PpacRbacRole to list values.

    .PARAMETER Scope
        Evaluation target such as /tenants/{0}. Fill all placeholders.

    .PARAMETER PrincipalType
        Type of principal for the assignment.

        Default: ApplicationUser

    .EXAMPLE
        PS C:\> Add-PpacRbacRoleMember -ServicePrincipalId "00000000-0000-0000-0000-000000000000" -Role "Power Platform Owner" -Scope "/tenants/{0}"

        Assigns the principal to the tenant.
        It uses -ServicePrincipalId to select the principal.
        It uses -Role to select the assignment target.
        It uses -Scope to select the evaluation target.
        It uses the default -PrincipalType ApplicationUser.

    .NOTES
        Author: Mötz Jensen (@Splaxi)

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Add-PpacRbacRoleMember {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ServicePrincipalId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Role,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Scope,

		[string] $PrincipalType = "ApplicationUser"
	)

	begin {

		$colRbacRoles = @(Get-BapRbacRoleCatalog)

		$objRole = $colRbacRoles |
		Where-Object { $_.roleDefinitionId -eq $Role } |
		Select-Object -First 1

		if ($null -eq $objRole) {
			$objRole = $colRbacRoles |
			Where-Object { $_.roleDefinitionName -eq $Role } |
			Select-Object -First 1
		}

		if ($null -eq $objRole) {
			$messageString = "The specified role: <c='em'>$Role</c> was not found. Please provide a valid role name. Try running the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because of invalid role name." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{ 'Content-Type' = 'application/json' }
		$hashHeaders.Add('Authorization', "Bearer $tokenValue")

		$tenantId = (Get-BapContext).TenantId
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$tmpScope = $Scope.Replace('/tenants/{0}', "/tenants/$tenantId")

		if ($tmpScope -like "*{*}*") {
			$tmpText = $tmpScope.Replace('{', "<c='em'>--").Replace('}', "--</c>")
			$messageString = "The specified scope: '$tmpText' is not valid. You need to fill out the missing scope details."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because of invalid scope." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colRoleMembers = Get-PpacRbacRoleMember `
			-ServicePrincipalId $ServicePrincipalId `
			-Role $objRole.roleDefinitionName |
		Where-Object {
			($_.Scope.TrimEnd('/') -eq $tmpScope.TrimEnd('/')) `
				-and ($_.PrincipalType -eq $PrincipalType)
		}

		if (-not ($null -eq $colRoleMembers)) {
			$colRoleMembers
			return
		}

		$payload = @{
			roleDefinitionId  = $objRole.roleDefinitionId
			principalObjectId = $ServicePrincipalId
			principalType     = $PrincipalType
			scope             = $tmpScope
		} | ConvertTo-Json

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$requestUri = 'https://api.powerplatform.com/authorization/roleAssignments?api-version={0}' `
			-f $apiVersion

		Invoke-RestMethod -Method Post `
			-Uri $requestUri `
			-Headers $hashHeaders `
			-ContentType $hashHeaders.'Content-Type' `
			-Body $payload `
			-StatusCodeVariable statusAssign > $null 4> $null

		if (-not ($statusAssign -like "2*")) {
			$messageString = "Failed to assign the role to the service principal. Verify that the service principal exists and the scope is correct. Try running the command <c='em'>Get-PpacRbacRoleMember</c> to see existing role assignments for service principals."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because assigning the role to the service principal in the Power Platform environment failed." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		Get-PpacRbacRoleMember `
			-ServicePrincipalId $ServicePrincipalId `
			-Role $objRole.roleDefinitionName |
		Where-Object {
			($_.Scope.TrimEnd('/') -eq $tmpScope.TrimEnd('/')) `
				-and ($_.PrincipalType -eq $PrincipalType)
		}
	}

	end {

	}
}
