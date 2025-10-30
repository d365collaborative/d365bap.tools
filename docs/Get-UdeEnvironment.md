---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeEnvironment

## SYNOPSIS
Gets UDE environments.

## SYNTAX

```
Get-UdeEnvironment [[-EnvironmentId] <String>] [-SkipVersionDetails] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves UDE environments.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeEnvironment
```

This will retrieve all available UDE environments.

### EXAMPLE 2
```
Get-UdeEnvironment -EnvironmentId "env-123"
```

This will retrieve the UDE environment with the specified environment ID.

### EXAMPLE 3
```
Get-UdeEnvironment -SkipVersionDetails
```

This will retrieve all available UDE environments without version details.

### EXAMPLE 4
```
Get-UdeEnvironment -AsExcelOutput
```

This will export the retrieved UDE environments to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipVersionDetails
Instructs the function to skip retrieving version details.

Will result in faster execution.

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
