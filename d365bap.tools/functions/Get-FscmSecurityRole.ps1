<#
    .SYNOPSIS
        Get security roles from a Finance and Operations environment.

    .DESCRIPTION
        Reads the SecurityRoles endpoint and returns one object per role. Each row carries identifiers and license details.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Name
        Filter on role identifier or role value.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -Name "System Administrator"

        Finds one role by exact value.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "System Administrator" to match one role.

    .EXAMPLE
        PS C:\> Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -Name "*admin*"

        Finds roles with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "*admin*" to match many roles.

    .EXAMPLE
        PS C:\> Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -AsExcelOutput

        Exports every role to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmSecurityRole {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmRole[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $Name = "*",

		[switch] $AsExcelOutput
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeadersFnO = @{
			"Authorization" = "Bearer $($tokenFnoOdataValue)"
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$localUri = '{0}/data/SecurityRoles' `
			-f $baseUri

		$colRolesRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$colRoles = $colRolesRaw |
		Where-Object {
			($_.SecurityRoleIdentifier -like $Name) `
				-or ($_.SecurityRoleIdentifier -eq $Name) `
				-or ($_.SecurityRoleName -like $Name) `
				-or ($_.SecurityRoleName -eq $Name)
		} | Sort-Object -Property 'SecurityRoleIdentifier'

		$colRole = @(
			$colRoles |
			Select-PSFObject -TypeName "D365Bap.Tools.FscmRole" `
				-ExcludeProperty "@odata.etag" `
				-Property `
				"SecurityRoleIdentifier as FscmRoleId",
			"SecurityRoleName as Name",
			"UserLicenseType as License",
			*
		)

		if ($AsExcelOutput) {
			$colRole |
			Export-Excel -WorksheetName "Get-FscmSecurityRole"
			return
		}

		$colRole
	}

	end {

	}
}
