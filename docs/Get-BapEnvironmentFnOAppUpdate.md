---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentFnOAppUpdate

## SYNOPSIS
Get FnO/FinOps Application update versions.

## SYNTAX

### Default (Default)
```
Get-BapEnvironmentFnOAppUpdate -EnvironmentId <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### Lowest
```
Get-BapEnvironmentFnOAppUpdate -EnvironmentId <String> [-Oldest] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### Highest
```
Get-BapEnvironmentFnOAppUpdate -EnvironmentId <String> [-Latest] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves available FnO/FinOps Application update versions for a given environment.

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123"
```

This will retrieve all available FnO/FinOps Application update versions for the specified environment.

### EXAMPLE 2
```
Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Latest
```

This will retrieve the latest available FnO/FinOps Application update version for the specified environment.

### EXAMPLE 3
```
Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Oldest
```

This will retrieve the oldest available FnO/FinOps Application update version for the specified environment.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Oldest
Instructs the function to return only the oldest available version.

```yaml
Type: SwitchParameter
Parameter Sets: Lowest
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Latest
Instructs the function to return only the latest available version.

```yaml
Type: SwitchParameter
Parameter Sets: Highest
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
