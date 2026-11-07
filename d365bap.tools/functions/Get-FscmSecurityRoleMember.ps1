<#
    .SYNOPSIS
        Get security role members from a Finance and Operations environment.

    .DESCRIPTION
        Reads membership endpoints and returns one object per assignment. Each row carries identifiers and contact details.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Role
        Role identifier or role value to select members from.

    .PARAMETER User
        Filter on user identifier or user value.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Administrator"

        Lists members of one role.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Role "System Administrator" to pick the role.

    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "-SYSADMIN-" -User "*john*"

        Finds members with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Role "-SYSADMIN-" to pick the role.
        It uses -User "*john*" to match many users.

    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Administrator" -AsExcelOutput

        Exports members of one role to a workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Role "System Administrator" to pick the role.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmSecurityRoleMember {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmUser[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Role,

		[SupportsWildcards()]
		[string] $User = "*",

		[switch] $AsExcelOutput
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$objSecRole = Get-FscmSecurityRole -EnvironmentId $EnvironmentId `
			-Name $Role |
		Select-Object -First 1

		if ($null -eq $objSecRole) {
			$messageString = "The supplied: <c='em'>$Role</c> didn't return any matching security details from the Environment. Please verify that the EnvironmentId & Role is correct - try running the <c='em'>Get-BapEnvironment</c> or <c='em'>Get-FscmSecurityRole</c> cmdlets."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		if (Test-PSFFunctionInterrupt) { return }

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

		$localUri = $baseUri + '/data/SystemUsers?$select=UserID,UserName,Alias,Company,UserInfo_language,Enabled'
		$colUsersRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$localUri = $baseUri + "/data/SecurityUserRoles?`$filter=SecurityRoleIdentifier eq '$($objSecRole.FscmRoleId)'"
		$colUserRolesRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$colUsers = $colUsersRaw |
		Where-Object {
			$_.UserID -in $colUserRolesRaw.UserId
		} | Sort-Object -Property UserID

		$colUsers = $colUsers |
		Where-Object {
			($_.UserID -like $User) `
				-or ($_.UserID -eq $User) `
				-or ($_.UserName -like $User) `
				-or ($_.UserName -eq $User) `
				-or ($_.Alias -like $User) `
				-or ($_.Alias -eq $User)
		} | Sort-Object -Property UserID

		$colUser = @(
			$colUsers |
			Select-PSFObject -TypeName "D365Bap.Tools.FscmUser" `
				-ExcludeProperty "@odata.etag", "Language", "UserID" `
				-Property "UserID as FscmUserId",
			"UserID as UserId",
			"Company as LegalEntity",
			"UserName as Name",
			"Alias as Upn",
			"UserInfo_language as Language",
			*
		)

		if ($AsExcelOutput) {
			$colUser |
			Export-Excel -WorksheetName "Get-FscmSecurityRoleMember"
			return
		}

		$colUser
	}

	end {

	}
}
