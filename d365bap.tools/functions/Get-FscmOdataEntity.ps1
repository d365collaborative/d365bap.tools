
<#
    .SYNOPSIS
        Get OData entity metadata from a Finance and Operations environment.

    .DESCRIPTION
        Retrieves entity metadata from the Finance and Operations /metadata/PublicEntities endpoint, returning schema information for each published OData entity.

        Results include the entity name, collection name, read-only state, configuration status, and joined lists of property names and navigation property names.

        Supports wildcard and exact matching against the Name and CollectionName (EntitySetName) fields.

    .PARAMETER EnvironmentId
        The ID of the environment to retrieve OData entity metadata from.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER Name
        The value to filter the results by.

        Filters against the entity Name and the CollectionName (EntitySetName) fields — any match on either will include the record.

        Supports wildcard characters for flexible matching.

        Default value is "*", which returns all published OData entities.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved entity metadata to an Excel file.

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv"

        This command retrieves metadata for all published OData entities in the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "SysAADClients"

        This command retrieves metadata for the OData entity named "SysAADClients" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "*Customer*"

        This command retrieves metadata for all OData entities whose Name or CollectionName contains "Customer" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "CustomersV3"

        This command retrieves metadata for the OData entity with the CollectionName "CustomersV3" from the environment "ContosoEnv".

        The filter matches against both the entity Name and the CollectionName (EntitySetName).

    .EXAMPLE
        PS C:\> Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -AsExcelOutput

        This command retrieves metadata for all published OData entities in the environment "ContosoEnv" and exports the results to an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataEntity {
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

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/metadata/PublicEntities'
        $colMetadataRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $resCol = $colMetadataRaw | Where-Object {
            ($_.Name -like $Name -or $_.Name -eq $Name) `
                -or ($_.EntitySetName -like $Name -or $_.EntitySetName -eq $Name)
        } | Sort-Object -Property 'Name' `
        | Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataEntity" `
            -ExcludeProperty "@odata.etag", `
            -Property "Name as EntityName",
        "EntitySetName as CollectionName",
        @{Name = "PropertiesList"; Expression = { $_.Properties.Name -join ", " } },
        @{Name = "NavigationPropertiesList"; Expression = { $_.NavigationProperties.Name -join ", " } },
        *

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmOdataEntity"
            return
        }

        $resCol
    }
    
    end {
        
    }
}