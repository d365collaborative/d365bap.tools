<#
    .SYNOPSIS
        Get DMF entity metadata from a Finance and Operations environment.

    .DESCRIPTION
        Reads the /Metadata/DataEntities endpoint and returns one object per DMF entity. Each row carries identifiers, category, and a joined list of fields.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Name
        Filter on entity, public entity, or public collection name.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv"

        Lists every DMF entity in the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.

    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "CustCustomerV3Entity"

        Finds one DMF entity by exact name.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "CustCustomerV3Entity" to match one entity.

    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "*Customer*"

        Finds DMF entities with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "*Customer*" to match many entities.

    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "CustomersV3"

        Finds DMF entities by public collection name.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "CustomersV3" to match the collection.

    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -AsExcelOutput

        Exports every DMF entity to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmDmfEntity {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmDmfEntity[]')]
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

		$localUri = '{0}/Metadata/DataEntities' `
			-f $baseUri

		$colMetadataRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$resCol = $colMetadataRaw |
		Where-Object {
			($_.Name -like $Name) `
				-or ($_.Name -eq $Name) `
				-or ($_.PublicEntityName -like $Name) `
				-or ($_.PublicEntityName -eq $Name) `
				-or ($_.PublicCollectionName -like $Name) `
				-or ($_.PublicCollectionName -eq $Name)
		} | Sort-Object -Property 'Name' |
		Select-PSFObject -TypeName "D365Bap.Tools.FscmDmfEntity" `
			-ExcludeProperty "@odata.etag" `
			-Property "Name as EntityName",
		*

		if ($AsExcelOutput) {
			$resCol |
			Export-Excel -WorksheetName "Get-FscmDmfEntity"
			return
		}

		$resCol
	}

	end {

	}
}
