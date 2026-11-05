<#
    .SYNOPSIS
        Remove an environment group RBAC assignment.

    .DESCRIPTION
        Deletes one Power Platform RBAC assignment from a group through the Power Platform API.

    .PARAMETER EnvironmentGroupId
        The unique identifier of the environment group.

    .PARAMETER RoleAssignmentId
        The unique identifier of the assignment to delete.

    .EXAMPLE
        PS C:\> Remove-PpacEnvironmentGroupRbacRoleMember -EnvironmentGroupId "00000000-0000-0000-0000-000000000000" -RoleAssignmentId "22222222-2222-2222-2222-222222222222"

        Deletes one group assignment.
        It uses -EnvironmentGroupId to select the group.
        It uses -RoleAssignmentId to select the assignment.

    .NOTES
        Author: d365bap.tools contributors

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Remove-PpacEnvironmentGroupRbacRoleMember {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentGroupId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $RoleAssignmentId
	)

	process {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			'Content-Type' = 'application/json'
			Authorization  = "Bearer $tokenValue"
		}

		$assignmentName = $RoleAssignmentId
		$shouldAffected = $assignmentName
		$shouldLabel = 'Remove group RBAC assignment'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uri = 'https://api.powerplatform.com/authorization/environmentGroups/{0}/roleAssignments/{1}?api-version={2}' `
			-f $EnvironmentGroupId,
		$RoleAssignmentId,
		$apiVersion

		try {
			Invoke-RestMethod -Method Delete `
				-Uri $uri `
				-Headers $hashHeaders `
				-ErrorAction Stop > $null
		}
		catch {
			$messageString = "Failed to delete the group RBAC assignment <c='em'>$RoleAssignmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because the group RBAC delete request failed.' `
				-Exception $_.Exception

			return
		}
	}
}
