---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeEnvironment

## SYNOPSIS
Gets UDE/USE environments.

## SYNTAX

### Default (Default)
```
Get-UdeEnvironment [-EnvironmentId <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### SkipVersion
```
Get-UdeEnvironment [-EnvironmentId <String>] [-SkipVersionDetails] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### UdeOnly
```
Get-UdeEnvironment [-EnvironmentId <String>] [-UdeOnly] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### UseOnly
```
Get-UdeEnvironment [-EnvironmentId <String>] [-UseOnly] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function retrieves UDE/USE environments.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeEnvironment
```

This will retrieve all available UDE/USE environments.

### EXAMPLE 2
```
Get-UdeEnvironment -EnvironmentId "env-123"
```

This will retrieve the UDE/USE environment with the specified environment ID.

### EXAMPLE 3
```
Get-UdeEnvironment -SkipVersionDetails
```

This will retrieve all available UDE/USE environments without version details.

### EXAMPLE 4
```
Get-UdeEnvironment -UdeOnly
```

This will retrieve only UDE environments.

### EXAMPLE 5
```
Get-UdeEnvironment -UseOnly
```

This will retrieve only USE environments.

### EXAMPLE 6
```
Get-UdeEnvironment -AsExcelOutput
```

This will export the retrieved UDE/USE environments to an Excel file.

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
Position: Named
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipVersionDetails
Instructs the function to skip retrieving version details.

Will result in faster execution, but will not include version information and tell you if the environment is UDE or USE.

```yaml
Type: SwitchParameter
Parameter Sets: SkipVersion
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UdeOnly
Instructs the function to only return UDE environments.

```yaml
Type: SwitchParameter
Parameter Sets: UdeOnly
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseOnly
Instructs the function to only return USE environments.

```yaml
Type: SwitchParameter
Parameter Sets: UseOnly
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
