<#
	.SYNOPSIS
		List Power Platform RBAC role definitions in the tenant.

	.DESCRIPTION
		Retrieves the Power Platform RBAC definitions through the Power
		Platform API.

		Each row identifies the definition, the scopes it can be assigned
		at, and the permissions it grants.

	.PARAMETER Role
		Role id, name, or description filter.

		Wildcards are accepted.

		Default: *

	.PARAMETER AsExcelOutput
		Instructs the cmdlet to output the results as an Excel file.

	.EXAMPLE
		PS C:\> Get-PpacRbacRole -Role "Power Platform *"

		Lists roles with a matching name.
		It uses -Role to filter on role id, name, or description and defaults to *.

	.EXAMPLE
		PS C:\> Get-PpacRbacRole -Role "*admin*" -AsExcelOutput

		Exports matching roles to an Excel workbook.
		It uses -Role to filter on role id, name, or description and defaults to *.
		It uses -AsExcelOutput to write an Excel file.

	.NOTES
		Author: d365bap.tools contributors
#>
function Get-PpacRbacRole {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacRbacRole[]', [object[]])]
	param (
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
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$requestUri = 'https://api.powerplatform.com/authorization/roleDefinitions?api-version={0}' `
			-f $script:BapApiVersions.PowerPlatform

		$resColRaw = Invoke-RestMethod `
			-Method Get `
			-Uri $requestUri `
			-Headers $hashHeaders 4> $null |
		Select-Object -ExpandProperty value

		try { Save-BapRbacRoleCatalog -Roles @($resColRaw) }
		catch {
			Write-PSFMessage -Level Verbose `
				-Message 'Role catalog cache update skipped.'
  }

		$resCol = $resColRaw |
		Where-Object {
			($_.roleDefinitionId -like $Role) `
				-or ($_.roleDefinitionName -like $Role) `
				-or ($_.description -like $Role)
		} | Select-PSFObject -TypeName 'D365Bap.Tools.PpacRbacRole' `
			-ExcludeProperty '@odata.etag', 'description', 'assignableScopes', 'restrictedScopes', 'permissions' `
			-Property `
			'roleDefinitionId as RoleId',
		'roleDefinitionName as Role',
		'description as Description',
		'assignableScopes as AssignableScopes',
		'restrictedScopes as RestrictedScopes',
		'permissions as Permissions',
		@{ Name = 'PermissionList'; Expression = { $_.permissions -join ',' } },
		@{ Name = 'RestrictedScopeList'; Expression = { $_.restrictedScopes -join ',' } },
		@{ Name = 'AssignableScopeList'; Expression = { $_.assignableScopes -join ',' } },
		*

		if ($AsExcelOutput) {
			$resCol |
			Export-Excel -WorksheetName 'Get-PpacRbacRole' `
				-WarningAction SilentlyContinue

			return
		}

		$resCol
	}

	end {

	}
}
