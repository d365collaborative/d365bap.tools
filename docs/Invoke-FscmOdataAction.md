---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-FscmOdataAction

## SYNOPSIS
Invokes an OData action in Finance and Supply Chain Management (FSCM).

## SYNTAX

```
Invoke-FscmOdataAction [-EnvironmentId] <String> [-Entity] <String> [-Name] <String> [[-EntityKey] <String>]
 [[-Parameters] <Hashtable>] [[-Payload] <String>] [-CrossCompany] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Calls an OData action exposed via the FSCM OData endpoint (/data).

The caller supplies the entity (Name or CollectionName) as the Entity, the action as the Name, and an optional pre-structured JSON payload for actions with input parameters.

Entity-set-bound actions are addressed as POST /data/\<CollectionName\>/Microsoft.Dynamics.DataEntities.\<ActionName\>, while entity-instance-bound actions additionally require the EntityKey and are addressed as POST /data/\<CollectionName\>(\<EntityKey\>)/Microsoft.Dynamics.DataEntities.\<ActionName\>.
Use Get-FscmOdataAction to discover the available actions and their binding kind.

A typical example is DataManagementEntity, which exposes GetApplicationBuildVersion, GetPlatformBuildVersion and GetApplicationVersion as actions bound to the DataManagementEntities entity set.
They take no input parameters and return Edm.String values.

## EXAMPLES

### EXAMPLE 1
```
Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntities" -Name "GetApplicationBuildVersion"
```

This will call the GetApplicationBuildVersion action bound to the DataManagementEntities entity set, which takes no input parameters.

### EXAMPLE 2
```
(Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity" -Name "GetPlatformBuildVersion").value
```

This will call the GetPlatformBuildVersion action (the Entity parameter accepts the entity Name as well as the collection name) and output the returned version string from the OData wrapper object.

### EXAMPLE 3
```
Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementDefinitionGroups" -Name "GetExecutionSummaryPageUrl" -Parameters @{ executionId = "ABC123" }
```

This will call the GetExecutionSummaryPageUrl action with the executionId input parameter supplied as a hashtable.

### EXAMPLE 4
```
Invoke-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementDefinitionGroups" -Name "GetExecutionSummaryPageUrl" -Payload '{"executionId":"ABC123"}'
```

This will call the GetExecutionSummaryPageUrl action with a raw JSON payload.

## PARAMETERS

### -EnvironmentId
The id of the environment you want to target.

This can be obtained from the Get-BapEnvironment cmdlet.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Entity
The OData entity to invoke the action on, either the entity Name or the CollectionName (entity set name).

E.g.
"DataManagementEntity" or "DataManagementEntities"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
The name of the OData action to invoke.

E.g.
"GetApplicationBuildVersion"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EntityKey
The key of a single entity instance, used only for actions bound to an entity instance (BindingKind BoundToEntityInstance).

This is the content inside the parentheses of the OData resource path, e.g.
"DataAreaId='USMF',JournalNumber='123'".

Not used for actions bound to an entity set (BindingKind BoundToEntitySet).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameters
The action input parameters (excluding the binding parameter) as a hashtable, e.g.
@{ executionId = "ABC123" }.

Cannot be combined with the Payload parameter.

Omit both Parameters and Payload when the action takes no input parameters - an empty JSON object ({}) is sent.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Payload
The raw JSON payload to send with the POST request, fully structured as expected by the OData action (excluding the binding parameter).

E.g.
'{"executionId":"ABC123"}'

Cannot be combined with the Parameters parameter.

Omit both Parameters and Payload when the action takes no input parameters - an empty JSON object ({}) is sent.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CrossCompany
Instructs the cmdlet to append "cross-company=true" to the request, invoking the action across all legal entities.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
