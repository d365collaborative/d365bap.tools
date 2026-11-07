<#
    .SYNOPSIS
        Get Entra registered applications from a Finance and Operations environment.

    .DESCRIPTION
        Reads the SysAADClients entity and returns one object per registered app. Each row carries identifiers for lookup.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER ClientId
        Filter on client, app, or user value.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv"

        Lists every registered app in the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "Admin"

        Finds apps by user value.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -ClientId "Admin" to match the user.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "*Integration*"

        Finds apps with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -ClientId "*Integration*" to match many apps.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -AsExcelOutput

        Exports every registered app to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmEntraApplication {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmEntraApplication[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $ClientId = "*",

		[switch] $AsExcelOutput
	)

	begin {
		if (Test-PSFFunctionInterrupt) { return }
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$colRaw = Get-FscmOdata -EnvironmentId $EnvironmentId `
			-Entity "SysAADClients"

		$colApp = @(
			$colRaw |
			Where-Object {
				($_.AadClientId -like $ClientId) `
					-or ($_.AadClientId -eq $ClientId) `
					-or ($_.Name -like $ClientId) `
					-or ($_.Name -eq $ClientId) `
					-or ($_.UserId -like $ClientId) `
					-or ($_.UserId -eq $ClientId)
			} | Select-PSFObject -TypeName "D365Bap.Tools.FscmEntraApplication" `
				-ExcludeProperty "@odata.etag" `
				-Property "AadClientId as ClientId",
			*
		)

		if ($AsExcelOutput) {
			$colApp |
			Export-Excel -WorksheetName "Get-FscmEntraApplication"
			return
		}

		$colApp
	}

	end {

	}
}
