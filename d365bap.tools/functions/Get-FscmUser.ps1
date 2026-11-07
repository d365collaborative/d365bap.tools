<#
    .SYNOPSIS
        Get records from a Finance and Operations environment.

    .DESCRIPTION
        Reads the SystemUsers endpoint and returns one object per record. Each row carries identifiers and contact details.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER User
        Filter on identifier or value.

        Default: *

    .PARAMETER IncludeMicrosoftAccounts
        Includes accounts hosted by the vendor.

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -User "Admin"

        Finds one record by exact value.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -User "Admin" to match one record.

    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -User "*admin*"

        Finds records with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -User "*admin*" to match many records.

    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -IncludeMicrosoftAccounts

        Lists every record including vendor accounts.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -IncludeMicrosoftAccounts to include vendor accounts.

    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -IncludeMicrosoftAccounts -AsExcelOutput

        Exports every record to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -IncludeMicrosoftAccounts to include vendor accounts.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmUser {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmUser[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $User = "*",

		[switch] $IncludeMicrosoftAccounts,

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

		$localUri = '{0}/data/SystemUsers' `
			-f $baseUri

		$colUsersRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$colUsers = $colUsersRaw |
		Where-Object {
			($_.UserID -like $User) `
				-or ($_.UserID -eq $User) `
				-or ($_.UserName -like $User) `
				-or ($_.UserName -eq $User) `
				-or ($_.Alias -like $User) `
				-or ($_.Alias -eq $User)
		} | Sort-Object -Property UserID

		if (-not $IncludeMicrosoftAccounts) {
			$colUsers = $colUsers |
			Where-Object {
				-Not (
					($_.Alias -like "*@dynamics.com") `
						-or ($_.Alias -like "*@microsoft.com") `
						-or ($_.Alias -like "*@onmicrosoft.com") `
						-or ($_.Alias -like "*@devtesttie.ccsctp.net") `
						-or ($_.Alias -like "*@capintegration01.onmicrosoft.com")
				)
			}
		}

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
			Export-Excel -WorksheetName "Get-FscmUser"
			return
		}

		$colUser
	}

	end {

	}
}
