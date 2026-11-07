<#
    .SYNOPSIS
        Get OData entity metadata from a Finance and Operations environment.

    .DESCRIPTION
        Reads the /metadata/PublicEntities endpoint and returns one object per OData entity. Each row carries identifiers and joined lists of fields.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Name
        Filter on entity or collection name.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv"

        Lists every OData entity in the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "SysAADClients"

        Finds one OData entity by exact name.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "SysAADClients" to match one entity.

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "*Customer*"

        Finds OData entities with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "*Customer*" to match many entities.

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "CustomersV3"

        Finds OData entities by collection name.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "CustomersV3" to match the collection.

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -AsExcelOutput

        Exports every OData entity to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataEntity {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmOdataEntity[]')]
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

		$localUri = '{0}/metadata/PublicEntities' `
			-f $baseUri

		$colMetadataRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$resCol = $colMetadataRaw |
		Where-Object {
			($_.Name -like $Name) `
				-or ($_.Name -eq $Name) `
				-or ($_.EntitySetName -like $Name) `
				-or ($_.EntitySetName -eq $Name)
		} | Sort-Object -Property 'Name' |
		Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataEntity" `
			-ExcludeProperty "@odata.etag" `
			-Property `
			"Name as EntityName",
		"EntitySetName as CollectionName",
		@{Name = "PropertiesList"; Expression = { $_.Properties.Name -join ", " } },
		@{Name = "NavigationPropertiesList"; Expression = { $_.NavigationProperties.Name -join ", " } },
		*

		if ($AsExcelOutput) {
			$resCol |
			Export-Excel -WorksheetName "Get-FscmOdataEntity"
			return
		}

		$resCol
	}

	end {

	}
}
