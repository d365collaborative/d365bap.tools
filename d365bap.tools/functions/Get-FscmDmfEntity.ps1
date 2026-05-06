
<#
    .SYNOPSIS
        Get DMF entity metadata from a Finance and Operations environment.
        
    .DESCRIPTION
        Retrieves entity metadata from the Finance and Operations /Metadata/DataEntities endpoint, returning schema information for each Data Management Framework (DMF) entity.
        
        Results include the entity name, public entity name, public collection name, category, and a joined list of field names.
        
        Supports wildcard and exact matching against the Name, PublicEntityName, and PublicCollectionName fields.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve DMF entity metadata from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The value to filter the results by.
        
        Filters against the entity Name, PublicEntityName, and PublicCollectionName fields — any match on any of the three will include the record.
        
        Supports wildcard characters for flexible matching.
        
        Default value is "*", which returns all DMF entities.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved entity metadata to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv"
        
        This command retrieves metadata for all DMF entities in the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "CustCustomerV3Entity"
        
        This command retrieves metadata for the DMF entity named "CustCustomerV3Entity" from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "*Customer*"
        
        This command retrieves metadata for all DMF entities whose Name, PublicEntityName, or PublicCollectionName contains "Customer" from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "CustomersV3"
        
        This command retrieves metadata for the DMF entity with the PublicCollectionName "CustomersV3" from the environment "ContosoEnv".
        
        The filter matches against the entity Name, PublicEntityName, and PublicCollectionName fields.
        
    .EXAMPLE
        PS C:\> Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves metadata for all DMF entities in the environment "ContosoEnv" and exports the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmDmfEntity {
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

        $localUri = $baseUri + '/Metadata/DataEntities'
        $colMetadataRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $resCol = $colMetadataRaw | Where-Object {
            ($_.Name -like $Name -or $_.Name -eq $Name) `
                -or ($_.PublicEntityName -like $Name -or $_.PublicEntityName -eq $Name) `
                -or ($_.PublicCollectionName -like $Name -or $_.PublicCollectionName -eq $Name)
        } | Sort-Object -Property 'Name' `
        | Select-PSFObject -TypeName "D365Bap.Tools.FscmDmfEntity" `
            -ExcludeProperty "@odata.etag" `
            -Property "Name as EntityName",
        *

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmDmfEntity"
            return
        }

        $resCol
    }

    end {

    }
}