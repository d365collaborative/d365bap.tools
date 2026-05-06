---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmRestService

## SYNOPSIS
Get REST service metadata from a Finance and Operations environment.

## SYNTAX

```
Get-FscmRestService [-EnvironmentId] <String> [[-Name] <String>] [[-TraverseTo] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves service metadata from the Finance and Operations /api/services endpoint.

Services are organized in a four-level hierarchy: service groups → services → operations → operation parameters.

The TraverseTo parameter controls how deep into the hierarchy the results are expanded.
Each returned object represents a single node at the requested level, with all higher-level identifier fields always populated.

Supports wildcard and exact matching against the ServiceGroupName, ServiceName, OperationName, and ParameterName fields - any match on a populated field will include the record.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmRestService -EnvironmentId "ContosoEnv"
```

This command retrieves all service groups from the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Service
```

This command retrieves all services within every service group from the environment "ContosoEnv".

### EXAMPLE 3
```
Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Operation -Name "*Sales*"
```

This command retrieves all operations whose service group name, service name, or operation name contains "Sales" from the environment "ContosoEnv".

### EXAMPLE 4
```
Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Detail -Name "SalesOrderService"
```

This command retrieves all operation parameter details within the "SalesOrderService" service group from the environment "ContosoEnv".

The filter matches against ServiceGroupName, ServiceName, OperationName, and ParameterName.

### EXAMPLE 5
```
Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Detail -AsExcelOutput
```

This command retrieves full parameter details for all REST services in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve REST service metadata from.

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

Filters against ServiceGroupName, ServiceName, OperationName, and ParameterName - any match on a populated field at the current traversal level will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all items at the requested traversal level.

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

### -TraverseTo
Controls how deep into the service hierarchy the results are expanded.

ServiceGroup: Returns one object per service group.
This is the default.
Service: Returns one object per service within each group.
Operation: Returns one object per operation within each service, including a joined list of parameter names and the return type.
Detail: Returns one object per parameter within each operation, including the parameter type.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: ServiceGroup
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to export the retrieved service metadata to an Excel file.

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
