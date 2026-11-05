<#
	.SYNOPSIS
		Assign an environment RBAC member.

	.DESCRIPTION
		Creates a scoped assignment through the Power Platform API and returns the new member.

	.PARAMETER EnvironmentId
		Target environment identifier.

	.PARAMETER ServicePrincipalId
		Member object id to assign.

	.PARAMETER Role
		Definition name or id to assign.

	.PARAMETER Scope
		Evaluation scope for the assignment.

	.PARAMETER PrincipalType
		Member type for the assignment.

		Default: ApplicationUser

	.EXAMPLE
		PS C:\> Add-PpacEnvironmentRbacRoleMember -EnvironmentId "00000000-0000-0000-0000-000000000000" -ServicePrincipalId "11111111-1111-1111-1111-111111111111" -Role "Environment Admin" -Scope "/tenants/00000000-0000-0000-0000-000000000000/environments/00000000-0000-0000-0000-000000000000"

		Assigns the member to the definition.
		It uses -EnvironmentId to select the environment.
		It uses -ServicePrincipalId to select the member.
		It uses -Role to select the definition.
		It uses -Scope to set the evaluation scope.
		It uses the default -PrincipalType ApplicationUser.

	.NOTES
		Author: d365bap.tools contributors

	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Add-PpacEnvironmentRbacRoleMember {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

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

		$pathMisc = Get-PSFConfigValue -FullName 'd365bap.tools.internal.misc.path'

		$colDefinitions = @()

		if (Test-Path -Path "$pathMisc\Ppac.Rbac.Roles.json") {
			$colDefinitions = @(Get-Content -Path "$pathMisc\Ppac.Rbac.Roles.json" `
					-Raw |
				ConvertFrom-Json)
		}

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

		$colMatched = @($colDefinitions |
			Where-Object {
				($_.roleDefinitionName -eq $Role) `
					-or ($_.roleDefinitionId -eq $Role)
			})

		if ($colMatched.Count -eq 0) {
			$messageString = "The specified role: <c='em'>$Role</c> was not found. Please provide a valid role name. Try running the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message 'Stopping because of invalid role name.' `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$definitionId = $colMatched[0].roleDefinitionId
		$definitionName = $colMatched[0].roleDefinitionName
		$memberName = $ServicePrincipalId

		$shouldAffected = $memberName
		$shouldLabel = "Assign environment member to '$definitionName'"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

		$apiVersion = $script:BapApiVersions.PowerPlatform

		$uri = 'https://api.powerplatform.com/authorization/environments/{0}/roleAssignments?api-version={1}' `
			-f $EnvironmentId,
		$apiVersion

		$hashBody = [ordered]@{
			principalObjectId = $ServicePrincipalId
			principalType     = $PrincipalType
			roleDefinitionId  = $definitionId
			scope             = $Scope
		}

		$bodyJson = $hashBody |
		ConvertTo-Json -Depth 10

		try {
			$objCreated = Invoke-RestMethod -Method Post `
				-Uri $uri `
				-Headers $hashHeaders `
				-Body $bodyJson `
				-ContentType 'application/json' `
				-ErrorAction Stop
		}
		catch {
			$messageString = "Failed to assign the member <c='em'>$ServicePrincipalId</c> in environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because the assignment request failed.' `
				-Exception $_.Exception

			return
		}

		$objCreated |
		Select-PSFObject -TypeName 'D365Bap.Tools.PpacRbacRoleAssignment' `
			-Property `
			'principalObjectId as ServicePrincipalId',
		'roleDefinitionId as RoleId',
		@{ Name = 'Role'; Expression = { $definitionName } },
		'principalType as PrincipalType',
		'id as RoleAssignmentId',
		'scope as Scope'
	}
}
