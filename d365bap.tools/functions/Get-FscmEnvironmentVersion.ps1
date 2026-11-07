<#
    .SYNOPSIS
        Get version numbers from a Finance and Operations environment.

    .DESCRIPTION
        Reads version actions and returns one object with application and platform details. Each row carries build identifiers.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER AsExcelOutput
        Exports the retrieved version details to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmEnvironmentVersion -EnvironmentId "ContosoEnv"

        Lists version details for the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.

    .EXAMPLE
        PS C:\> Get-FscmEnvironmentVersion -EnvironmentId "ContosoEnv" -AsExcelOutput

        Exports version details to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmEnvironmentVersion {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmEnvironmentVersion[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

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

		$hashActions = [ordered]@{
			ApplicationVersion = 'GetApplicationVersion'
			ApplicationBuild   = 'GetApplicationBuildVersion'
			PlatformBuild      = 'GetPlatformBuildVersion'
		}

		$hashProps = [ordered]@{}

		foreach ($itemKey in $hashActions.Keys) {
			$localUri = '{0}/data/DataManagementEntities/Microsoft.Dynamics.DataEntities.{1}' `
				-f $baseUri,
			$hashActions[$itemKey]

			$resValue = Invoke-RestMethod -Method Post `
				-Uri $localUri `
				-Headers $hashHeadersFnO `
				-ContentType 'application/json' `
				-Body '{}' `
				-ErrorAction Stop |
			Select-Object -ExpandProperty value

			$hashProps[$itemKey] = $resValue
		}

		$res = [PSCustomObject]$hashProps |
		Select-PSFObject -TypeName "D365Bap.Tools.FscmEnvironmentVersion" `
			-Property `
			ApplicationVersion,
		ApplicationBuild,
		PlatformBuild

		if ($AsExcelOutput) {
			$res |
			Export-Excel -WorksheetName "Get-FscmEnvironmentVersion"
			return
		}

		$res
	}

	end {

	}
}
