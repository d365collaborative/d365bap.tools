---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-UnifiedEnvironmentModule

## SYNOPSIS
Remove UDE environment modules.

## SYNTAX

```
Remove-UnifiedEnvironmentModule [-EnvironmentId] <String> [[-ModuleId] <String>] [[-Name] <String>] [-Force]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes UDE environment modules (msprov_fnomodule records) for a specified environment.

Modules are matched by module id and name.
Nothing is removed unless the -Force switch is supplied.
Without -Force the cmdlet lists the modules that would be removed.

## EXAMPLES

### EXAMPLE 1
```
Remove-UnifiedEnvironmentModule -EnvironmentId "env-123" -ModuleId "a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6"
```

This will show the module that would be removed for the specified environment id.
It will NOT remove the module yet, allowing you to review it before deciding to remove it.

### EXAMPLE 2
```
Remove-UnifiedEnvironmentModule -EnvironmentId "env-123" -ModuleId "a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6" -Force
```

This will remove the specified module for the specified environment id without further confirmation.

### EXAMPLE 3
```
Get-UnifiedEnvironmentModule -EnvironmentId "env-123" | Remove-UnifiedEnvironmentModule -Force
```

This will remove all modules returned for the specified environment id without further confirmation.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

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

### -ModuleId
The id of the module that you want to remove.

Supports wildcard characters for flexible matching against the module id.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: *
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
The name of the module that you want to remove.

Supports wildcard characters for flexible matching against the module name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: *
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Force
Instructs the function to proceed with removing the modules.

Nothing happens unless this parameter is supplied.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
