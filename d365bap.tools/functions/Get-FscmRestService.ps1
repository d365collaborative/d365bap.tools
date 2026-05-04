
<#
    .SYNOPSIS
        Get REST service metadata from a Finance and Operations environment.

    .DESCRIPTION
        Retrieves service metadata from the Finance and Operations /api/services endpoint.

        Services are organized in a four-level hierarchy: service groups → services → operations → operation parameters.

        The TraverseTo parameter controls how deep into the hierarchy the results are expanded. Each returned object represents a single node at the requested level, with all higher-level identifier fields always populated.

        Supports wildcard and exact matching against the ServiceGroupName, ServiceName, OperationName, and ParameterName fields — any match on a populated field will include the record.

    .PARAMETER EnvironmentId
        The ID of the environment to retrieve REST service metadata from.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER Name
        The value to filter the results by.

        Filters against ServiceGroupName, ServiceName, OperationName, and ParameterName — any match on a populated field at the current traversal level will include the record.

        Supports wildcard characters for flexible matching.

        Default value is "*", which returns all items at the requested traversal level.

    .PARAMETER TraverseTo
        Controls how deep into the service hierarchy the results are expanded.

        ServiceGroup: Returns one object per service group. This is the default.
        Service: Returns one object per service within each group.
        Operation: Returns one object per operation within each service, including a joined list of parameter names and the return type.
        Detail: Returns one object per parameter within each operation, including the parameter type.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved service metadata to an Excel file.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv"

        This command retrieves all service groups from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Service

        This command retrieves all services within every service group from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Operation -Name "*Sales*"

        This command retrieves all operations whose service group name, service name, or operation name contains "Sales" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Detail -Name "SalesOrderService"

        This command retrieves all operation parameter details within the "SalesOrderService" service group from the environment "ContosoEnv".

        The filter matches against ServiceGroupName, ServiceName, OperationName, and ParameterName.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Detail -AsExcelOutput

        This command retrieves full parameter details for all REST services in the environment "ContosoEnv" and exports the results to an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmRestService {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [string] $TraverseTo = "ServiceGroup",

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

        $localUri = $baseUri + '/api/services'
        $resStatusCode = $null
        $responseRoot = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO `
            -StatusCodeVariable 'resStatusCode' `
            -SkipHttpErrorCheck

        if ($resStatusCode -ne 200) {
            [PSCustomObject]@{
                PSTypeName    = "D365Bap.Tools.FscmRestService"
                ServiceGroup  = $null
                Service       = $null
                Operation     = $null
                Parameter     = $null
                ParameterType = $null
                ReturnType    = $null
                ErrorMessage  = $responseRoot | ConvertTo-Json -Depth 10
            }
            return
        }

        $resColRaw = $responseRoot | Select-Object -ExpandProperty ServiceGroups | Where-Object {
            $_.Name -like $Name
        } | ForEach-Object -Parallel {
            $serviceGroup = $_
            $baseUri = $using:baseUri
            $headersFnO = $using:headersFnO
            $TraverseTo = $using:TraverseTo

            $objHash = [Ordered]@{
                ServiceGroup = $serviceGroup.Name
                ErrorMessage = ''
            }

            if ($TraverseTo -eq "ServiceGroup") {
                [PSCustomObject]$objHash
                return
            }

            $localUri = $baseUri + "/api/services/$($serviceGroup.Name)"
            $resStatusCode = $null
            $responseGroup = Invoke-RestMethod -Method Get `
                -Uri $localUri `
                -Headers $headersFnO `
                -StatusCodeVariable 'resStatusCode' `
                -SkipHttpErrorCheck

            if ($resStatusCode -ne 200) {
                $objHash.ErrorMessage = $responseGroup | ConvertTo-Json -Depth 10

                [PSCustomObject]$objHash
                return
            }

            foreach ($service in ($responseGroup | Select-Object -ExpandProperty Services)) {
                $objHash.Service = $service.Name

                if ($TraverseTo -eq "Service") {
                    [PSCustomObject]$objHash
                    continue
                }

                $localUri = $baseUri + "/api/services/$($serviceGroup.Name)/$($service.Name)"
                $resStatusCode = $null
                $responseService = Invoke-RestMethod -Method Get `
                    -Uri $localUri `
                    -Headers $headersFnO `
                    -StatusCodeVariable 'resStatusCode' `
                    -SkipHttpErrorCheck

                if ($resStatusCode -ne 200) {
                    $objHash.ErrorMessage = $responseService | ConvertTo-Json -Depth 10

                    [PSCustomObject]$objHash
                    continue
                }

                foreach ($operation in ($responseService | Select-Object -ExpandProperty Operations)) {
                    $objHash.Operation = $operation.Name
                    $objHash.ReturnType = $operation.ReturnType
                        
                    if ($TraverseTo -eq "Operation") {
                        [PSCustomObject]$objHash
                        continue
                    }

                    $localUri = $baseUri + "/api/services/$($serviceGroup.Name)/$($service.Name)/$($operation.Name)"
                    $resStatusCode = $null
                    $responseOperation = Invoke-RestMethod -Method Get `
                        -Uri $localUri `
                        -Headers $headersFnO `
                        -StatusCodeVariable 'resStatusCode' `
                        -SkipHttpErrorCheck

                    if ($resStatusCode -ne 200) {
                        $objHash.ErrorMessage = $responseOperation | ConvertTo-Json -Depth 10

                        [PSCustomObject]$objHash
                        continue
                    }
                        
                    foreach ($parameter in $responseOperation.Parameters) {
                        $objHash.Parameter = $parameter.Name
                        $objHash.ParameterType = $parameter.Type
                    
                        [PSCustomObject]$objHash
                        continue
                    }
                }
            }
        } -ThrottleLimit 10

        $resCol = $resColRaw | Select-PSFObject `
            -TypeName "D365Bap.Tools.FscmRestService" `
            -Property ServiceGroup `
            , Service `
            , Operation `
            , ReturnType `
            , Parameter `
            , ParameterType `
            , ErrorMessage | Sort-Object -Property 'ServiceGroup', 'Service', 'Operation', 'Parameter'

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmRestService"
            return
        }

        $resCol
    }

    end {

    }
}
