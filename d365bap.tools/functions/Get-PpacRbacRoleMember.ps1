<#
    .SYNOPSIS
        Get members of PPAC RBAC roles in the tenant.

    .DESCRIPTION
        Gets members of PPAC RBAC roles in the tenant. This command is used to retrieve the list of service principals that are assigned to PPAC RBAC roles in Power Platform.

    .PARAMETER ServicePrincipalId
        Service principal object id filter. Wildcards are accepted.

        Default: *

    .PARAMETER Role
        Role id, name, or description filter. Wildcards are accepted.

        Default: *

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacRbacRoleMember

        Lists all PPAC RBAC role assignments.

    .EXAMPLE
        PS C:\> Get-PpacRbacRoleMember -Role "*admin*"

        Lists assignments that match the filter.
        It uses -Role to filter on role id, name, or description.

    .EXAMPLE
        PS C:\> Get-PpacRbacRoleMember -ServicePrincipalId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports assignments for one service principal.
        It uses -ServicePrincipalId to select the service principal.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Get-PpacRbacRoleMember {
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment[]', [object[]])]
	param (
		[SupportsWildcards()]
		[string] $ServicePrincipalId = '*',

		[SupportsWildcards()]
		[string] $Role = '*',

		[switch] $AsExcelOutput
	)

	begin {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			'Content-Type' = 'application/json'
			Authorization  = "Bearer $tokenValue"
		}

		$pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uriDefinitions = 'https://api.powerplatform.com/authorization/roleDefinitions?api-version={0}' `
			-f $apiVersion

		$rolesCachePath = "$pathMisc\Ppac.Rbac.Roles.json"

		if (Test-Path -LiteralPath $rolesCachePath) {
			$rbacRoles = Get-Content -Path $rolesCachePath `
				-Raw |
			ConvertFrom-Json
		}
		else {
			$rbacRoles = Invoke-RestMethod -Method Get `
				-Uri $uriDefinitions `
				-Headers $hashHeaders 4> $null |
			Select-Object -ExpandProperty value
		}

		$hashRoleNames = @{}
		foreach ($itemRole in @($rbacRoles)) {
			$hashRoleNames[$itemRole.roleDefinitionId] = $itemRole.roleDefinitionName
		}

		$colRoleIds = $rbacRoles |
		Where-Object {
			($_.roleDefinitionId -like $Role) `
				-or ($_.roleDefinitionName -like $Role) `
				-or ($_.description -like $Role)
		} | Select-Object -ExpandProperty roleDefinitionId

		if (($null -eq $colRoleIds) `
				-or (@($colRoleIds).Count -eq 0)) {
			$messageString = "The specified role: <c='em'>$Role</c> was not found. Please provide a valid role name. Try running the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because of invalid role name." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$uriAssignments = 'https://api.powerplatform.com/authorization/roleAssignments?api-version={0}' `
			-f $apiVersion

		$colAssignmentsRaw = Invoke-RestMethod -Method Get `
			-Uri $uriAssignments `
			-Headers $hashHeaders 4> $null |
		Select-Object -ExpandProperty value

		$colRes = $colAssignmentsRaw |
		Where-Object {
			($_.principalObjectId -like $ServicePrincipalId) `
				-and ($_.roleDefinitionId -in $colRoleIds)
		} | Select-PSFObject -TypeName 'D365Bap.Tools.PpacRbacRoleAssignment' `
			-ExcludeProperty '@odata.etag' `
			-Property 'principalObjectId as ServicePrincipalId', `
			'roleDefinitionId as RoleId', `
		@{ Name = 'Role'; Expression = { $hashRoleNames[$_.roleDefinitionId] } }, `
			*

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacRbacRoleMember' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}

	end {

	}
}
