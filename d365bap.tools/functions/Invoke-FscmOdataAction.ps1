
<#
    .SYNOPSIS
        Invokes an OData action in Finance and Supply Chain Management (FSCM).
        
    .DESCRIPTION
        Calls an OData action exposed via the FSCM OData endpoint (/data).
        
        The caller supplies the entity (Name or CollectionName) as the Entity, the action as the Name, and an optional pre-structured JSON payload for actions with input parameters.
        
        Entity-set-bound actions are addressed as POST /data/<CollectionName>/Microsoft.Dynamics.DataEntities.<ActionName>, while entity-instance-bound actions additionally require the EntityKey and are addressed as POST /data/<CollectionName>(<EntityKey>)/Microsoft.Dynamics.DataEntities.<ActionName>. Use Get-FscmOdataAction to discover the available actions and their binding kind.
        
        A typical example is DataManagementEntity, which exposes GetApplicationBuildVersion, GetPlatformBuildVersion and GetApplicationVersion as actions bound to the DataManagementEntities entity set. They take no input parameters and return Edm.String values.
        
    .PARAMETER EnvironmentId
        The id of the environment you want to target.
        
        This can be obtained from the Get-BapEnvironment cmdlet.
        
    .PARAMETER Entity
        The OData entity to invoke the action on, either the entity Name or the CollectionName (entity set name).
        
        E.g. "DataManagementEntity" or "DataManagementEntities"
        
    .PARAMETER Name
        The name of the OData action to invoke.
        
        E.g. "GetApplicationBuildVersion"
        
    .PARAMETER EntityKey
        The key of a single entity instance, used only for actions bound to an entity instance (BindingKind BoundToEntityInstance).
        
        This is the content inside the parentheses of the OData resource path, e.g. "DataAreaId='USMF',JournalNumber='123'".
        
        Not used for actions bound to an entity set (BindingKind BoundToEntitySet).
        
    .PARAMETER Parameters
        The action input parameters (excluding the binding parameter) as a hashtable, e.g. @{ executionId = "ABC123" }.
        
        Cannot be combined with the Payload parameter.
        
        Omit both Parameters and Payload when the action takes no input parameters — an empty JSON object ({}) is sent.
        
    .PARAMETER Payload
        The raw JSON payload to send with the POST request, fully structured as expected by the OData action (excluding the binding parameter).
        
        E.g. '{"executionId":"ABC123"}'
        
        Cannot be combined with the Parameters parameter.
        
        Omit both Parameters and Payload when the action takes no input parameters — an empty JSON object ({}) is sent.
        
    .PARAMETER CrossCompany
        Instructs the cmdlet to append "cross-company=true" to the request, invoking the action across all legal entities.
        
    .EXAMPLE
        PS C:\> Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntities" -Name "GetApplicationBuildVersion"
        
        This will call the GetApplicationBuildVersion action bound to the DataManagementEntities entity set, which takes no input parameters.
        
    .EXAMPLE
        PS C:\> (Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity" -Name "GetPlatformBuildVersion").value
        
        This will call the GetPlatformBuildVersion action (the Entity parameter accepts the entity Name as well as the collection name) and output the returned version string from the OData wrapper object.
        
    .EXAMPLE
        PS C:\> Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementDefinitionGroups" -Name "GetExecutionSummaryPageUrl" -Parameters @{ executionId = "ABC123" }
        
        This will call the GetExecutionSummaryPageUrl action with the executionId input parameter supplied as a hashtable.
        
    .EXAMPLE
        PS C:\> Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementDefinitionGroups" -Name "GetExecutionSummaryPageUrl" -Payload '{"executionId":"ABC123"}'
        
        This will call the GetExecutionSummaryPageUrl action with a raw JSON payload.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-FscmOdataAction {
    [CmdletBinding()]
    [OutputType('System.Object')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter(Mandatory = $true)]
        [string] $Entity,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [string] $EntityKey,

        [hashtable] $Parameters,

        [string] $Payload,

        [switch] $CrossCompany
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
            "Accept"        = "application/json"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        if ($PSBoundParameters.ContainsKey('Parameters') -and -not [string]::IsNullOrWhiteSpace($Payload)) {
            $messageString = "The <c='em'>Parameters</c> and <c='em'>Payload</c> parameters cannot be combined. Supply the action input either as a hashtable or as raw JSON."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because both Parameters and Payload were supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # Resolve the entity (accepts both the entity Name and the CollectionName) and the action from live metadata.
        $localUri = $baseUri + '/metadata/PublicEntities'
        $colMetadataRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $entityObj = $colMetadataRaw | Where-Object {
            ($_.Name -eq $Entity) -or ($_.EntitySetName -eq $Entity)
        } | Select-Object -First 1

        if ($null -eq $entityObj) {
            $messageString = "The supplied Entity: <c='em'>$Entity</c> didn't match any published OData entity (Name or CollectionName). Try running the <c='em'>Get-FscmOdataAction</c> cmdlet to discover the available entities and actions."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the entity was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $actionObj = @($entityObj.Actions) | Where-Object {
            $_.Name -eq $Name
        } | Select-Object -First 1

        if ($null -eq $actionObj) {
            $availableNames = (@($entityObj.Actions) | Select-Object -ExpandProperty Name | Sort-Object) -join ", "

            if ([string]::IsNullOrEmpty($availableNames)) { $availableNames = "(no actions)" }
            $messageString = "The supplied action Name: <c='em'>$Name</c> was NOT found on the entity <c='em'>$($entityObj.Name)</c> ($($entityObj.EntitySetName)). Available actions: <c='em'>$availableNames</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the OData action was NOT found on the entity." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $bindingKind = "$($actionObj.BindingKind)"
        $collectionName = "$($entityObj.EntitySetName)"

        $bindingParam = @($actionObj.Parameters) | Select-Object -First 1
        $namespace = "Microsoft.Dynamics.DataEntities"

        if ($null -ne $bindingParam -and -not [string]::IsNullOrEmpty($bindingParam.Type.TypeName) -and $bindingParam.Type.TypeName.Contains('.')) {
            $namespace = $bindingParam.Type.TypeName.Substring(0, $bindingParam.Type.TypeName.LastIndexOf('.'))
        }

        $qualifiedAction = "$namespace.$($actionObj.Name)"

        if ($bindingKind -eq "BoundToEntityInstance") {
            if ([string]::IsNullOrWhiteSpace($EntityKey)) {
                $messageString = "The action <c='em'>$($actionObj.Name)</c> is bound to an entity instance (BindingKind BoundToEntityInstance) and requires the <c='em'>EntityKey</c> parameter, e.g. -EntityKey 'DataAreaId=''USMF'',JournalNumber=''123'''."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because EntityKey is required for entity-instance-bound actions." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            $localUri = "$baseUri/data/$collectionName($EntityKey)/$qualifiedAction"
        }
        else {
            if (-not [string]::IsNullOrWhiteSpace($EntityKey)) {
                Write-PSFMessage -Level Verbose -Message "The EntityKey parameter is ignored because the action $($actionObj.Name) is bound to the entity set ($bindingKind)."
            }

            $localUri = "$baseUri/data/$collectionName/$qualifiedAction"
        }

        if ($CrossCompany) {
            $localUri += "?cross-company=true"
        }

        if (-not [string]::IsNullOrWhiteSpace($Payload)) {
            $body = $Payload
        }
        elseif ($PSBoundParameters.ContainsKey('Parameters')) {
            $body = $Parameters | ConvertTo-Json -Depth 10 -Compress
        }
        else {
            $body = '{}'
        }

        $resStatusCode = $null

        $resService = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersFnO `
            -ContentType 'application/json;charset=utf-8' `
            -Body $body `
            -StatusCodeVariable 'resStatusCode' `
            -SkipHttpErrorCheck

        if (-not "$resStatusCode" -like "2*") {
            $messageString = "Invoking the FSCM OData action <c='em'>$($actionObj.Name)</c> on <c='em'>$collectionName</c> failed with status code <c='em'>$resStatusCode</c>."
            Write-PSFMessage -Level Warning -Message $messageString
            Stop-PSFFunction -Message "Stopping because the OData action call failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $resService
    }

    end {
        
    }
}
