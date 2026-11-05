
<#
    .SYNOPSIS
        Remove a PPAC RBAC role assignment from the tenant.

    .DESCRIPTION
        Deletes a PPAC RBAC role assignment in the tenant. This revokes permissions previously granted to a service principal in Power Platform.

    .PARAMETER RoleAssignmentId
        The id of the role assignment to remove. Use Get-PpacRbacRoleMember to find it.

    .EXAMPLE
        PS C:\> Remove-PpacRbacRoleMember -RoleAssignmentId "00000000-0000-0000-0000-000000000000"

        Removes the role assignment.
        It uses -RoleAssignmentId to select the assignment.

    .NOTES
        Author: Mötz Jensen (@Splaxi)

    .LINK
        https://learn.microsoft.com/en-us/rest/api/power-platform/authorization/role-based-access-control/delete-role-assignment
#>
function Remove-PpacRbacRoleMember {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $RoleAssignmentId
	)

	begin {
		$token = Get-PSFConfigValue -FullName "d365bap.tools.internal.ppac.rbac.token"

		if ($null -eq $token) {
			Write-PSFMessage -Level Warning `
				-Message "No authentication token found for PPAC RBAC operations. Please run <c='em'>Set-PpacRbacContext</c> to authenticate first."

			Stop-PSFFunction -Message "Stopping because of missing authentication token." `
				-Exception $([System.Exception]::new("Missing authentication token for PPAC RBAC operations."))

			return
		}

		$hashHeaders = @{ 'Content-Type' = 'application/json' }
		$hashHeaders.Add('Authorization', $token)
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$apiVersion = $script:BapApiVersions.PowerPlatform

		$uri = 'https://api.powerplatform.com/authorization/roleAssignments/{0}?api-version={1}' `
			-f $RoleAssignmentId,
		$apiVersion

		Invoke-RestMethod -Method Delete `
			-Uri $uri `
			-Headers $hashHeaders > $null 4> $null
	}

	end {

	}
}
