
<#
    .SYNOPSIS
        Get OData action metadata from a Finance and Operations environment.
        
    .DESCRIPTION
        Retrieves action metadata from the Finance and Operations /metadata/PublicEntities endpoint, returning one object per OData action bound to an entity or an entity set.
        
        Results include the entity name, collection name, action name, binding kind, return type and a joined list of parameter names.
        
        Supports wildcard and exact matching against the entity (Name and CollectionName) and the action Name fields.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve OData action metadata from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Entity
        The value to filter the results by.
        
        Filters against the entity Name and the CollectionName (EntitySetName) fields — any match on either will include the entity's actions.
        
        Supports wildcard characters for flexible matching.
        
        Default value is "*", which returns actions from all published OData entities.
        
    .PARAMETER Name
        The value to filter the results by.
        
        Filters against the action Name field.
        
        Supports wildcard characters for flexible matching.
        
        Default value is "*", which returns all actions of the selected entities.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved action metadata to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity"
        
        This command retrieves all OData actions bound to the DataManagementEntity entity (GetApplicationBuildVersion, GetPlatformBuildVersion, GetApplicationVersion, query) from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntities" -Name "*Version*"
        
        This command retrieves all OData actions with "Version" in the name from the DataManagementEntities collection in the environment "ContosoEnv". The Entity filter matches both the entity Name and the CollectionName.
        
    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Name "*Version*"
        
        This command retrieves every OData action with "Version" in the name across all entities in the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity" -AsExcelOutput
        
        This command retrieves all OData actions of the DataManagementEntity entity in the environment "ContosoEnv" and exports the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataAction {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Entity = "*",

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

        $colEntities = $colMetadataRaw | Where-Object {
            ($_.Name -like $Entity -or $_.Name -eq $Entity) `
                -or ($_.EntitySetName -like $Entity -or $_.EntitySetName -eq $Entity)
        }

        $resCol = @(foreach ($entityObj in $colEntities) {
                $entityName = "$($entityObj.Name)"
                $collectionName = "$($entityObj.EntitySetName)"

                foreach ($actionObj in @($entityObj.Actions | Where-Object { $_.Name -like $Name -or $_.Name -eq $Name })) {
                    $bindingKind = "$($actionObj.BindingKind)"

                    $allParams = @($actionObj.Parameters | Where-Object { $null -ne $_ })
                    # The first parameter is the binding parameter (the entity / entity collection itself).
                    $bindingParam = $allParams | Select-Object -First 1
                    $inputParams = @($allParams | Select-Object -Skip 1)

                    $bindingParamName = "$($bindingParam.Name)"
                    $namespace = "Microsoft.Dynamics.DataEntities"

                    if (-not [string]::IsNullOrEmpty($bindingParam.Type.TypeName) -and $bindingParam.Type.TypeName.Contains('.')) {
                        $namespace = $bindingParam.Type.TypeName.Substring(0, $bindingParam.Type.TypeName.LastIndexOf('.'))
                    }

                    $qualifiedAction = "$namespace.$($actionObj.Name)"

                    if ($bindingKind -eq "BoundToEntityInstance") {
                        $endpoint = "/data/$collectionName(<key>)/$qualifiedAction"
                    }
                    else {
                        $endpoint = "/data/$collectionName/$qualifiedAction"
                    }

                    $returnType = ""
                    $returnIsCollection = $false

                    if ($null -ne $actionObj.ReturnType -and -not [string]::IsNullOrEmpty($actionObj.ReturnType.TypeName)) {
                        $returnType = "$($actionObj.ReturnType.TypeName)"
                        $returnIsCollection = [bool]$actionObj.ReturnType.IsCollection
                    }

                    $paramSummaries = @($inputParams | ForEach-Object {
                            $paramType = "$($_.Type.TypeName)"

                            if ([bool]$_.Type.IsCollection) { $paramType = "Collection($paramType)" }

                            "$($_.Name): $paramType"
                        } | Sort-Object)

                    [PSCustomObject][ordered]@{
                        EntityName         = $entityName
                        CollectionName     = $collectionName
                        ActionName         = "$($actionObj.Name)"
                        BindingKind        = $bindingKind
                        ReturnType         = $returnType
                        ReturnIsCollection = $returnIsCollection
                        ParameterCount     = $inputParams.Count
                        ParametersList     = ($paramSummaries -join ", ")
                        BindingParameter   = $bindingParamName
                        Endpoint           = $endpoint
                        FieldLookup        = "$($actionObj.FieldLookup)"
                    }
                }
            })

        $resCol = @(
            $resCol | Sort-Object -Property 'EntityName', 'ActionName' | `
                Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataAction" -Property *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmOdataAction"
            return
        }

        $resCol
    }
    
    end {
        
    }
}
