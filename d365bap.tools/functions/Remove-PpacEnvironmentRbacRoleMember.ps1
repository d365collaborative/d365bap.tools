<#
	.SYNOPSIS
		Remove an environment RBAC assignment.

	.DESCRIPTION
		Deletes a scoped assignment through the Power Platform API.

	.PARAMETER EnvironmentId
		Target environment identifier.

	.PARAMETER RoleAssignmentId
		Assignment identifier to remove.

	.EXAMPLE
		PS C:\> Remove-PpacEnvironmentRbacRoleMember -EnvironmentId "00000000-0000-0000-0000-000000000000" -RoleAssignmentId "11111111-1111-1111-1111-111111111111"

		Removes the assignment from the environment.
		It uses -EnvironmentId to select the environment.
		It uses -RoleAssignmentId to select the assignment.

	.NOTES
		Author: d365bap.tools contributors

	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Remove-PpacEnvironmentRbacRoleMember {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $RoleAssignmentId
	)

	process {
		$token = Get-PSFConfigValue -FullName 'd365bap.tools.internal.ppac.rbac.token'

		if ($null -eq $token) {
			Write-PSFMessage -Level Warning `
				-Message "No authentication token found for PPAC RBAC operations. Please run <c='em'>Set-PpacRbacContext</c> to authenticate first."

			Stop-PSFFunction -Message 'Stopping because of missing authentication token.' `
				-Exception $([System.Exception]::new('Missing authentication token for PPAC RBAC operations.'))

			return
		}

		$hashHeaders = @{
			'Content-Type' = 'application/json'
		}

		$hashHeaders.Add('Authorization', $token)

		$apiVersion = $script:BapApiVersions.PowerPlatform

		$uri = 'https://api.powerplatform.com/authorization/environments/{0}/roleAssignments/{1}?api-version={2}' `
			-f $EnvironmentId,
		$RoleAssignmentId,
		$apiVersion

		$assignmentName = $RoleAssignmentId

		$shouldAffected = $assignmentName
		$shouldLabel = 'Remove environment assignment'

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		try {
			Invoke-RestMethod -Method Delete `
				-Uri $uri `
				-Headers $hashHeaders `
				-ErrorAction Stop > $null
		}
		catch {
			$messageString = "Failed to remove the assignment <c='em'>$RoleAssignmentId</c> from environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because the removal request failed.' `
				-Exception $_.Exception

			return
		}
	}
}
