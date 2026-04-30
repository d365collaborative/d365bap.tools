
<#
    .SYNOPSIS
        Get OData entity metadata from a Power Platform / Dataverse environment.

    .DESCRIPTION
        Retrieves entity metadata from the Dataverse /api/data/v9.2/EntityDefinitions endpoint, returning schema information for each published OData entity.

        Results include the entity logical name, collection name, schema name, and whether the entity is a custom entity or managed solution component.

        Supports wildcard and exact matching against the LogicalName and EntitySetName fields.

    .PARAMETER EnvironmentId
        The ID of the environment to retrieve OData entity metadata from.

        Can be either the environment name or the environment GUID (PPAC).

    .PARAMETER Name
        The value to filter the results by.

        Filters against the entity LogicalName and the EntitySetName (OData collection name) fields — any match on either will include the record.

        Supports wildcard characters for flexible matching.

        Default value is "*", which returns all OData entities.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved entity metadata to an Excel file.

    .EXAMPLE
        PS C:\> Get-PpeOdataEntity -EnvironmentId "ContosoEnv"

        This command retrieves metadata for all OData entities in the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -Name "account"

        This command retrieves metadata for the OData entity named "account" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -Name "*customer*"

        This command retrieves metadata for all OData entities whose LogicalName or EntitySetName contains "customer" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -Name "accounts"

        This command retrieves metadata for the OData entity with the EntitySetName "accounts" from the environment "ContosoEnv".

        The filter matches against both the entity LogicalName and the EntitySetName.

    .EXAMPLE
        PS C:\> Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -AsExcelOutput

        This command retrieves metadata for all OData entities in the environment "ContosoEnv" and exports the results to an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpeOdataEntity {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $AsExcelOutput
    )

    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.PpacEnvUri.TrimEnd('/')

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/api/data/v9.2/EntityDefinitions'
        $colMetadataRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersWebApi | Select-Object -ExpandProperty value

        $resCol = $colMetadataRaw | Where-Object {
            ($_.LogicalName -like $Name -or $_.LogicalName -eq $Name) `
                -or ($_.EntitySetName -like $Name -or $_.EntitySetName -eq $Name)
        } | Sort-Object -Property 'LogicalName' `
        | Select-PSFObject -TypeName "D365Bap.Tools.PpeOdataEntity" `
            -ExcludeProperty "@odata.etag", "MetadataId" `
            -Property "LogicalName as EntityName",
        "LogicalName as Name",
        "EntitySetName as CollectionName",
        *

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpeOdataEntity"
            return
        }

        $resCol
    }

    end {

    }
}
