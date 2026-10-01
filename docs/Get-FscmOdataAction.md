---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmOdataAction

## SYNOPSIS
Get OData action metadata from a Finance and Operations environment.

## SYNTAX

```
Get-FscmOdataAction [-EnvironmentId] <String> [[-Entity] <String>] [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves action metadata from the Finance and Operations /metadata/PublicEntities endpoint, returning one object per OData action bound to an entity or an entity set.

Results include the entity name, collection name, action name, binding kind, return type and a joined list of parameter names.

Supports wildcard and exact matching against the entity (Name and CollectionName) and the action Name fields.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity"
```

This command retrieves all OData actions bound to the DataManagementEntity entity (GetApplicationBuildVersion, GetPlatformBuildVersion, GetApplicationVersion, query) from the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntities" -Name "*Version*"
```

This command retrieves all OData actions with "Version" in the name from the DataManagementEntities collection in the environment "ContosoEnv".
The Entity filter matches both the entity Name and the CollectionName.

### EXAMPLE 3
```
Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Name "*Version*"
```

This command retrieves every OData action with "Version" in the name across all entities in the environment "ContosoEnv".

### EXAMPLE 4
```
Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity" -AsExcelOutput
```

This command retrieves all OData actions of the DataManagementEntity entity in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve OData action metadata from.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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
The value to filter the results by.

Filters against the entity Name and the CollectionName (EntitySetName) fields - any match on either will include the entity's actions.

Supports wildcard characters for flexible matching.

Default value is "*", which returns actions from all published OData entities.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
The value to filter the results by.

Filters against the action Name field.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all actions of the selected entities.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to export the retrieved action metadata to an Excel file.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
