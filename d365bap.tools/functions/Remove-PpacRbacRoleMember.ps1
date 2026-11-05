
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
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{ 'Content-Type' = 'application/json' }
		$hashHeaders.Add('Authorization', "Bearer $tokenValue")
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
