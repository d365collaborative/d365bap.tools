---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UnifiedEnvironment

## SYNOPSIS
Get Unified Environment in Power Platform Admin Center (PPAC).

## SYNTAX

### Default (Default)
```
Get-UnifiedEnvironment [-EnvironmentId <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### SkipVersion
```
Get-UnifiedEnvironment [-EnvironmentId <String>] [-SkipVersionDetails] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### UdeOnly
```
Get-UnifiedEnvironment [-EnvironmentId <String>] [-UdeOnly] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### UseOnly
```
Get-UnifiedEnvironment [-EnvironmentId <String>] [-UseOnly] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves information about Unified Environments in Power Platform Admin Center (PPAC).

Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).

## EXAMPLES

### EXAMPLE 1
```
Get-UnifiedEnvironment
```

This will retrieve all available UDE/USE environments.

### EXAMPLE 2
```
Get-UnifiedEnvironment -EnvironmentId "env-123"
```

This will retrieve the UDE/USE environment with the specified environment ID.

### EXAMPLE 3
```
Get-UnifiedEnvironment -SkipVersionDetails
```

This will retrieve all available UDE/USE environments without version details.

### EXAMPLE 4
```
Get-UnifiedEnvironment -UdeOnly
```

This will retrieve only UDE environments.

### EXAMPLE 5
```
Get-UnifiedEnvironment -UseOnly
```

This will retrieve only USE environments.

### EXAMPLE 6
```
Get-UnifiedEnvironment -AsExcelOutput
```

This will export the retrieved UDE/USE environments to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve.

Supports wildcard patterns.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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
