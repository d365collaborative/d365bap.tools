
<#
    .SYNOPSIS
        Get custom APIs from a Power Platform / Dataverse environment.
        
    .DESCRIPTION
        Retrieves custom API definitions from the Dataverse /api/data/v9.2/customapis endpoint, returning discovery information for each API.
        
        Results show the unique name, whether the API is a Function (HTTP GET) or an Action (HTTP POST), the binding type (Global, Entity, EntityCollection) and whether the API is private.
        
        A private API (IsPrivate) is hidden from the Web API $metadata document and code generation tools, but it can still be invoked through the Web API and the SOAP Organization Service (Execute) when the unique name is known. No custom API is SOAP-only.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve custom APIs from.
        
        Can be either the environment name or the environment GUID (PPAC).
        
    .PARAMETER Name
        The value to filter the results by.
        
        Filters against the custom API UniqueName, Name and DisplayName fields — any match on either will include the record.
        
        Supports wildcard characters for flexible matching.
        
        Default value is "*", which returns all custom APIs.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved custom APIs to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpeCustomApi -EnvironmentId "ContosoEnv"
        
        This command retrieves all custom APIs in the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-PpeCustomApi -EnvironmentId "ContosoEnv" -Name "msprov_*"
        
        This command retrieves all custom APIs whose unique name starts with "msprov_" from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-PpeCustomApi -EnvironmentId "ContosoEnv" -Name "*fino*"
        
        This command retrieves all custom APIs whose unique name, name or display name contains "fino" from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-PpeCustomApi -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves all custom APIs in the environment "ContosoEnv" and exports the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpeCustomApi {
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
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal"
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }

        $bindingLabels = @{
            0 = "Global"
            1 = "Entity"
            2 = "EntityCollection"
        }

        $processingStepLabels = @{
            0 = "None"
            1 = "Async Only"
            2 = "Sync and Async"
        }

        $parameterTypeLabels = @{
            0  = "Boolean"
            1  = "DateTime"
            2  = "Decimal"
            3  = "Entity"
            4  = "EntityCollection"
            5  = "EntityReference"
            6  = "Float"
            7  = "Integer"
            8  = "Money"
            9  = "Picklist"
            10 = "String"
            11 = "StringArray"
            12 = "Guid"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/api/data/v9.2/customapis?$select=uniquename,name,displayname,description,isfunction,isprivate,bindingtype,boundentitylogicalname,allowedcustomprocessingsteptype,workflowsdkstepenabled,executeprivilegename&$expand=CustomAPIRequestParameters($select=uniquename,type,isoptional),CustomAPIResponseProperties($select=uniquename,type)'

        $colApisRaw = @()
        $nextUri = $localUri

        do {
            $page = Invoke-RestMethod -Method Get `
                -Uri $nextUri `
                -Headers $headersWebApi 4> $null

            $colApisRaw += @($page.value)
            $nextUri = $page.'@odata.nextLink'
        } while (-not [string]::IsNullOrEmpty($nextUri))

        $colApis = $colApisRaw | Where-Object {
            $localDisplayName = $_.displayname

            if ($localDisplayName -isnot [string] -and $null -ne $localDisplayName.UserLocalizedLabel.Label) {
                $localDisplayName = $localDisplayName.UserLocalizedLabel.Label
            }

            ($_.uniquename -like $Name -or $_.uniquename -eq $Name) `
                -or ($_.name -like $Name -or $_.name -eq $Name) `
                -or ($localDisplayName -like $Name -or $localDisplayName -eq $Name)
        }

        $entitySetByLogicalName = @{}

        $boundLogicalNames = @($colApis | Where-Object {
                [int]$_.bindingtype -ne 0 -and -not [string]::IsNullOrEmpty($_.boundentitylogicalname)
            } | Select-Object -ExpandProperty boundentitylogicalname -Unique)

        $batchSize = 50

        for ($i = 0; $i -lt $boundLogicalNames.Count; $i += $batchSize) {
            $batch = @($boundLogicalNames[$i..([Math]::Min($i + $batchSize - 1, $boundLogicalNames.Count - 1))])

            try {
                $entityFilter = ($batch | ForEach-Object { "LogicalName eq '$_'" }) -join ' or '
                $entityUri = $baseUri + "/api/data/v9.2/EntityDefinitions?`$select=LogicalName,EntitySetName&`$filter=$entityFilter"

                $colEntities = Invoke-RestMethod -Method Get `
                    -Uri $entityUri `
                    -Headers $headersWebApi 4> $null | `
                    Select-Object -ExpandProperty value

                foreach ($entityObj in $colEntities) {
                    $entitySetByLogicalName["$($entityObj.LogicalName)"] = "$($entityObj.EntitySetName)"
                }
            }
            catch {
                Write-PSFMessage -Level Verbose -Message "Failed to resolve entity set names for bound custom APIs. WebApiPath will fall back to the bound entity logical name. Error: $($_.Exception.Message)"
            }
        }

        $resCol = @(foreach ($apiObj in $colApis) {
                $isFunction = [bool]$apiObj.isfunction
                $isPrivate = [bool]$apiObj.isprivate

                if ($isFunction) {
                    $operationType = "Function"
                    $httpMethod = "GET"
                }
                else {
                    $operationType = "Action"
                    $httpMethod = "POST"
                }

                $bindingValue = [int]$apiObj.bindingtype
                $binding = $bindingLabels[$bindingValue]

                if ([string]::IsNullOrEmpty($binding)) { $binding = "$bindingValue" }

                $boundEntity = "$($apiObj.boundentitylogicalname)"
                $entitySet = $entitySetByLogicalName[$boundEntity]

                if ([string]::IsNullOrEmpty($entitySet)) { $entitySet = $boundEntity }

                if ($binding -eq "Global") {
                    $webApiPath = "/api/data/v9.2/$($apiObj.uniquename)"
                }
                elseif ($binding -eq "Entity") {
                    $webApiPath = "/api/data/v9.2/$entitySet(<id>)/Microsoft.Dynamics.CRM.$($apiObj.uniquename)"
                }
                else {
                    $webApiPath = "/api/data/v9.2/$entitySet/Microsoft.Dynamics.CRM.$($apiObj.uniquename)"
                }

                if ($isFunction) { $webApiPath += "(...)" }

                $displayName = $apiObj.displayname

                if ($displayName -isnot [string] -and $null -ne $displayName.UserLocalizedLabel.Label) {
                    $displayName = $displayName.UserLocalizedLabel.Label
                }

                $requestParams = @($apiObj.CustomAPIRequestParameters | Where-Object { $null -ne $_ })
                $responseProps = @($apiObj.CustomAPIResponseProperties | Where-Object { $null -ne $_ })

                $requestSummaries = @($requestParams | ForEach-Object {
                        $typeLabel = $parameterTypeLabels[[int]$_.type]

                        if ([string]::IsNullOrEmpty($typeLabel)) { $typeLabel = "$($_.type)" }

                        if ([bool]$_.isoptional) { $optionality = "Optional" }
                        else { $optionality = "Required" }

                        "$($_.uniquename) ($typeLabel, $optionality)"
                    } | Sort-Object)

                $responseSummaries = @($responseProps | ForEach-Object {
                        $typeLabel = $parameterTypeLabels[[int]$_.type]

                        if ([string]::IsNullOrEmpty($typeLabel)) { $typeLabel = "$($_.type)" }

                        "$($_.uniquename) ($typeLabel)"
                    } | Sort-Object)

                $processingStepValue = [int]$apiObj.allowedcustomprocessingsteptype
                $processingStep = $processingStepLabels[$processingStepValue]

                if ([string]::IsNullOrEmpty($processingStep)) { $processingStep = "$processingStepValue" }

                [PsCustomObject][ordered]@{
                    Name                    = "$($apiObj.uniquename)"
                    UniqueName              = "$($apiObj.uniquename)"
                    DisplayName             = "$displayName"
                    OperationType           = $operationType
                    HttpMethod              = $httpMethod
                    Binding                 = $binding
                    BoundEntity             = $boundEntity
                    EntitySet               = $entitySet
                    WebApiPath              = $webApiPath
                    SoapRequest             = "$($apiObj.uniquename)"
                    IsPrivate               = $isPrivate
                    InMetadata              = (-not $isPrivate)
                    WorkflowEnabled         = [bool]$apiObj.workflowsdkstepenabled
                    AllowedProcessingStep   = $processingStep
                    ExecutePrivilege        = "$($apiObj.executeprivilegename)"
                    RequestParameterCount   = $requestParams.Count
                    RequestParameters       = ($requestSummaries -join ", ")
                    ResponsePropertyCount   = $responseProps.Count
                    ResponseProperties      = ($responseSummaries -join ", ")
                    Description             = "$($apiObj.description)"
                }
            })

        $resCol = @(
            $resCol | Sort-Object -Property Name | `
                Select-PSFObject -TypeName "D365Bap.Tools.PpeCustomApi" -Property *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpeCustomApi"
            return
        }

        $resCol
    }

    end {

    }
}