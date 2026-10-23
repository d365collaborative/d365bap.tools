---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UnifiedEnvironmentOperationError

## SYNOPSIS
Get Finance and Operations operation errors for a Unified environment.

## SYNTAX

```
Get-UnifiedEnvironmentOperationError [-EnvironmentId] <String> [[-MaxResults] <Int32>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to retrieve recent Finance and Operations operation errors for a Unified environment

## EXAMPLES

### EXAMPLE 1
```
Get-UnifiedEnvironmentOperationError -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
```

This will fetch up to 20 recent operation errors for the specified environment.

### EXAMPLE 2
```
Get-UnifiedEnvironmentOperationError -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -MaxResults 100
```

This will fetch up to 100 recent operation errors for the specified environment.

### EXAMPLE 3
```
Get-UnifiedEnvironmentOperationError -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
```

This will fetch recent operation errors for the specified environment.
It will output the results directly into an Excel file, that will automatically open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -MaxResults
The maximum number of operation errors to return.

Default it 20.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 20
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the function to export the results to an Excel file.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
