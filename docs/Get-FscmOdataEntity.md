---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmOdataEntity

## SYNOPSIS
Get OData entity metadata from a Finance and Operations environment.

## SYNTAX

```
Get-FscmOdataEntity [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves entity metadata from the Finance and Operations /metadata/PublicEntities endpoint, returning schema information for each published OData entity.

Results include the entity name, collection name, read-only state, configuration status, and joined lists of property names and navigation property names.

Supports wildcard and exact matching against the Name and CollectionName (EntitySetName) fields.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmOdataEntity -EnvironmentId "ContosoEnv"
```

This command retrieves metadata for all published OData entities in the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "SysAADClients"
```

This command retrieves metadata for the OData entity named "SysAADClients" from the environment "ContosoEnv".

### EXAMPLE 3
```
Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "*Customer*"
```

This command retrieves metadata for all OData entities whose Name or CollectionName contains "Customer" from the environment "ContosoEnv".

### EXAMPLE 4
```
Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -Name "CustomersV3"
```

This command retrieves metadata for the OData entity with the CollectionName "CustomersV3" from the environment "ContosoEnv".

The filter matches against both the entity Name and the CollectionName (EntitySetName).

### EXAMPLE 5
```
Get-FscmOdataEntity -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves metadata for all published OData entities in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve OData entity metadata from.

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

### -Name
The value to filter the results by.

Filters against the entity Name and the CollectionName (EntitySetName) fields - any match on either will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all published OData entities.

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

### -AsExcelOutput
Instructs the cmdlet to export the retrieved entity metadata to an Excel file.

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
