---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpeOdataEntity

## SYNOPSIS
Get OData entity metadata from a Power Platform / Dataverse environment.

## SYNTAX

```
Get-PpeOdataEntity [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves entity metadata from the Dataverse /api/data/v9.2/EntityDefinitions endpoint, returning schema information for each published OData entity.

Results include the entity logical name, collection name, schema name, and whether the entity is a custom entity or managed solution component.

Supports wildcard and exact matching against the LogicalName and EntitySetName fields.

## EXAMPLES

### EXAMPLE 1
```
Get-PpeOdataEntity -EnvironmentId "ContosoEnv"
```

This command retrieves metadata for all OData entities in the environment "ContosoEnv".

### EXAMPLE 2
```
Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -Name "account"
```

This command retrieves metadata for the OData entity named "account" from the environment "ContosoEnv".

### EXAMPLE 3
```
Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -Name "*customer*"
```

This command retrieves metadata for all OData entities whose LogicalName or EntitySetName contains "customer" from the environment "ContosoEnv".

### EXAMPLE 4
```
Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -Name "accounts"
```

This command retrieves metadata for the OData entity with the EntitySetName "accounts" from the environment "ContosoEnv".

The filter matches against both the entity LogicalName and the EntitySetName.

### EXAMPLE 5
```
Get-PpeOdataEntity -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves metadata for all OData entities in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve OData entity metadata from.

Can be either the environment name or the environment GUID (PPAC).

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

Filters against the entity LogicalName and the EntitySetName (OData collection name) fields - any match on either will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all OData entities.

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
