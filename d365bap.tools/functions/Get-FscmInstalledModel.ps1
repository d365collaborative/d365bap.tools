<#
    .SYNOPSIS
        Get installed models from a Finance and Operations environment.

    .DESCRIPTION
        Reads the installed modules action and returns one object per installed model. Each row carries display, version, module, and publisher details.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Name
        Filter on display, model, or module value.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv"

        Lists every installed model in the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.

    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -Name "*Application*"

        Finds installed models with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "*Application*" to match many models.

    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -Name "ApplicationSuite"

        Finds installed models by module value.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "ApplicationSuite" to match the module.

    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -AsExcelOutput

        Exports every installed model to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmInstalledModel {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmInstalledModel[]')]
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

		$localUri = '{0}/data/SystemNotifications/Microsoft.Dynamics.DataEntities.GetInstalledModules' `
			-f $baseUri

		$colModulesRaw = Invoke-RestMethod -Method Post `
			-Uri $localUri `
			-Headers $hashHeadersFnO `
			-ContentType 'application/json' `
			-Body '{}' |
		Select-Object -ExpandProperty value

		$colParsed = foreach ($itemEntry in $colModulesRaw) {
			$tmpProps = @{}

			foreach ($itemPart in ($itemEntry -split '\s*\|\s*')) {
				$idx = $itemPart.IndexOf(':')
				if ($idx -gt 0) {
					$key = $itemPart.Substring(0, $idx).Trim()
					$val = $itemPart.Substring($idx + 1).Trim()
					$tmpProps[$key] = $val
				}
			}

			[PSCustomObject][ordered]@{
				DisplayName = $tmpProps['DisplayName']
				Name        = $tmpProps['Name']
				Version     = $tmpProps['Version']
				Module      = $tmpProps['Module']
				Publisher   = $tmpProps['Publisher']
			}
		}

		$resCol = $colParsed |
		Where-Object {
			($_.Name -like $Name) `
				-or ($_.Name -eq $Name) `
				-or ($_.DisplayName -like $Name) `
				-or ($_.DisplayName -eq $Name) `
				-or ($_.Module -like $Name) `
				-or ($_.Module -eq $Name)
		} | Sort-Object -Property 'DisplayName' |
		Select-PSFObject -TypeName "D365Bap.Tools.FscmInstalledModel" `
			-Property `
			DisplayName,
		Name,
		Version,
		Module,
		Publisher

		if ($AsExcelOutput) {
			$resCol |
			Export-Excel -WorksheetName "Get-FscmInstalledModel"
			return
		}

		$resCol
	}

	end {

	}
}
