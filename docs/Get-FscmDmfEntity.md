---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmDmfEntity

## SYNOPSIS
Get DMF entity metadata from a Finance and Operations environment.

## SYNTAX

```
Get-FscmDmfEntity [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves entity metadata from the Finance and Operations /Metadata/DataEntities endpoint, returning schema information for each Data Management Framework (DMF) entity.

Results include the entity name, public entity name, public collection name, category, and a joined list of field names.

Supports wildcard and exact matching against the Name, PublicEntityName, and PublicCollectionName fields.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmDmfEntity -EnvironmentId "ContosoEnv"
```

This command retrieves metadata for all DMF entities in the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "CustCustomerV3Entity"
```

This command retrieves metadata for the DMF entity named "CustCustomerV3Entity" from the environment "ContosoEnv".

### EXAMPLE 3
```
Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "*Customer*"
```

This command retrieves metadata for all DMF entities whose Name, PublicEntityName, or PublicCollectionName contains "Customer" from the environment "ContosoEnv".

### EXAMPLE 4
```
Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -Name "CustomersV3"
```

This command retrieves metadata for the DMF entity with the PublicCollectionName "CustomersV3" from the environment "ContosoEnv".

The filter matches against the entity Name, PublicEntityName, and PublicCollectionName fields.

### EXAMPLE 5
```
Get-FscmDmfEntity -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves metadata for all DMF entities in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve DMF entity metadata from.

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

Filters against the entity Name, PublicEntityName, and PublicCollectionName fields - any match on any of the three will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all DMF entities.

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
