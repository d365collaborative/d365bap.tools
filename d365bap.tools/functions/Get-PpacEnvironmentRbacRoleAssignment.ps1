<#
	.SYNOPSIS
		Search environment RBAC role assignments through the Power Platform API.

	.DESCRIPTION
		Searches environment role assignments through the Power Platform API.

		Only supplied filters are sent and matching assignments are returned.

	.PARAMETER EnvironmentId
		The unique identifier of the environment to search within.

	.PARAMETER Scope
		The scope to search, such as a tenant or environment scope path.

	.PARAMETER ServicePrincipalId
		The object id of the principal to filter the search by.

	.PARAMETER PrincipalType
		The principal type to filter by, such as user or application.

	.PARAMETER Permission
		The permission name to filter the search results by.

	.PARAMETER IncludeParentScopes
		Includes assignments from parent scopes in the search results.

	.PARAMETER IncludeNestedScopes
		Includes assignments from nested scopes in the search results.

	.PARAMETER ExpandEnvironmentGroups
		Expands environment group memberships in the search results.

	.PARAMETER ExpandEnvironmentClusters
		Expands environment cluster memberships in the search results.

	.PARAMETER ExpandSecurityGroups
		Expands security group memberships in the search results.

	.PARAMETER IncludeVirtualEntraRoleAssignments
		Includes virtual Entra role assignments in the search results.

	.PARAMETER ContinuationToken
		The continuation token for the next page of search results.

	.PARAMETER AsExcelOutput
		Instructs the cmdlet to output the results as an Excel file.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000" -Scope "/tenants/00000000-0000-0000-0000-000000000000"

		Searches assignments within the environment.
		It uses -EnvironmentId to select the environment.
		It uses -Scope to select the search scope.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000" -Scope "/tenants/00000000-0000-0000-0000-000000000000" -ServicePrincipalId "11111111-1111-1111-1111-111111111111" -PrincipalType "ApplicationUser" -Permission "Read"

		Searches assignments for a principal with a permission filter.
		It uses -EnvironmentId to select the environment.
		It uses -Scope to select the search scope.
		It uses -ServicePrincipalId to select the principal.
		It uses -PrincipalType to select the principal type.
		It uses -Permission to select the permission filter.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000" -Scope "/tenants/00000000-0000-0000-0000-000000000000" -IncludeParentScopes -IncludeNestedScopes -AsExcelOutput

		Exports assignments including parent and nested scopes.
		It uses -EnvironmentId to select the environment.
		It uses -Scope to select the search scope.
		It uses -IncludeParentScopes to include parent scopes.
		It uses -IncludeNestedScopes to include nested scopes.
		It uses -AsExcelOutput to write an Excel file.

	.EXAMPLE
		PS C:\> Get-PpacEnvironmentRbacRoleAssignment -EnvironmentId "00000000-0000-0000-0000-000000000000" -Scope "/tenants/00000000-0000-0000-0000-000000000000" -ExpandEnvironmentGroups -ExpandEnvironmentClusters -ExpandSecurityGroups -IncludeVirtualEntraRoleAssignments -ContinuationToken "abc"

		Searches assignments with expanded memberships and paging.
		It uses -EnvironmentId to select the environment.
		It uses -Scope to select the search scope.
		It uses -ExpandEnvironmentGroups to expand group memberships.
		It uses -ExpandEnvironmentClusters to expand cluster memberships.
		It uses -ExpandSecurityGroups to expand security memberships.
		It uses -IncludeVirtualEntraRoleAssignments to include virtual assignments.
		It uses -ContinuationToken to continue a paged search.

	.NOTES
		Author: d365bap.tools contributors

	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment

	.LINK
		https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2
#>
function Get-PpacEnvironmentRbacRoleAssignment {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacRbacRoleAssignment[]', [object[]])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Scope,

		[ValidateNotNullOrEmpty()]
		[string] $ServicePrincipalId,

		[ValidateNotNullOrEmpty()]
		[string] $PrincipalType,

		[ValidateNotNullOrEmpty()]
		[string] $Permission,

		[switch] $IncludeParentScopes,

		[switch] $IncludeNestedScopes,

		[switch] $ExpandEnvironmentGroups,

		[switch] $ExpandEnvironmentClusters,

		[switch] $ExpandSecurityGroups,

		[switch] $IncludeVirtualEntraRoleAssignments,

		[ValidateNotNullOrEmpty()]
		[string] $ContinuationToken,

		[switch] $AsExcelOutput
	)

	process {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			Authorization  = "Bearer $tokenValue"
			'Content-Type' = 'application/json'
		}

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$uri = 'https://api.powerplatform.com/authorization/environments/{0}/roleAssignments/search?api-version={1}' `
			-f $EnvironmentId,
		$apiVersion

		$hashBody = [ordered]@{
			scope = $Scope
		}

		if ($PSBoundParameters.ContainsKey('ServicePrincipalId')) { $hashBody['principalObjectId'] = $ServicePrincipalId }
		if ($PSBoundParameters.ContainsKey('PrincipalType')) { $hashBody['principalType'] = $PrincipalType }
		if ($PSBoundParameters.ContainsKey('Permission')) { $hashBody['permission'] = $Permission }
		if ($IncludeParentScopes) { $hashBody['includeParentScopes'] = $true }
		if ($IncludeNestedScopes) { $hashBody['includeNestedScopes'] = $true }
		if ($ExpandEnvironmentGroups) { $hashBody['expandEnvironmentGroups'] = $true }
		if ($ExpandEnvironmentClusters) { $hashBody['expandEnvironmentClusters'] = $true }
		if ($ExpandSecurityGroups) { $hashBody['expandSecurityGroups'] = $true }
		if ($IncludeVirtualEntraRoleAssignments) { $hashBody['includeVirtualEntraRoleAssignments'] = $true }
		if ($PSBoundParameters.ContainsKey('ContinuationToken')) { $hashBody['continuationToken'] = $ContinuationToken }

		$jsonBody = $hashBody |
		ConvertTo-Json -Depth 20

		try {
			$result = Invoke-RestMethod -Method Post `
				-Uri $uri `
				-Headers $hashHeaders `
				-Body $jsonBody `
				-ContentType 'application/json' `
				-ErrorAction Stop
		}
		catch {
			if (($_.Exception.Response.StatusCode -eq 404) `
					-and ($_.ErrorDetails.Message -match '"code"\s*:\s*"RouteNotFound"')) {
				throw [System.NotSupportedException]::new('The service does not expose the environment RBAC assignment search route for this API version. Use Get-PpacEnvironmentRbacRoleMember to list assignments; search expansion options are unavailable.', $_.Exception)
			}

			$messageString = "Failed to search environment role assignments in environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the role assignment search request failed." `
				-Exception $_.Exception

			return
		}

		$colRes = @(
			$result.value |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacRbacRoleAssignment' `
				-Property `
				'principalObjectId as ServicePrincipalId',
			'roleDefinitionId as RoleId',
			'principalType as PrincipalType',
			'scope as Scope',
			'roleAssignmentId as RoleAssignmentId'
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentRbacRoleAssignment' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
