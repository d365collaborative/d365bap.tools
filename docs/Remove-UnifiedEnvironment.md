---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-UnifiedEnvironment

## SYNOPSIS
Remove a unified environment from a Power Platform tenant.

## SYNTAX

```
Remove-UnifiedEnvironment [-EnvironmentId] <String> [-Force] [-WaitForCompletion]
 [[-DeletionTimeoutMinutes] <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes a unified environment (UDE/USE) and everything inside it from the tenant.

Nothing is removed unless the -Force switch is supplied.
Without -Force the cmdlet lists the environment and the resources that would be removed together with it.

Only unified environments are supported.
Other environment types must be removed from the Power Platform Admin Center (PPAC).

A removed environment can be recovered from the Power Platform Admin Center (PPAC) for a limited period, normally seven days.

## EXAMPLES

### EXAMPLE 1
```
Remove-UnifiedEnvironment -EnvironmentId "env-123"
```

This will show the environment and the resources that would be removed for the specified environment id.
It will NOT remove the environment yet, allowing you to review it before deciding to remove it.

### EXAMPLE 2
```
Remove-UnifiedEnvironment -EnvironmentId "env-123" -Force
```

This will remove the specified environment without further confirmation.

### EXAMPLE 3
```
Remove-UnifiedEnvironment -EnvironmentId "env-123" -Force -WaitForCompletion
```

This will remove the specified environment without further confirmation.
It will wait until the environment has been removed from the tenant.

### EXAMPLE 4
```
Remove-UnifiedEnvironment -EnvironmentId "env-123" -Force -WaitForCompletion -DeletionTimeoutMinutes 120
```

This will remove the specified environment without further confirmation.
It will wait up to 120 minutes for the environment to be removed from the tenant.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name or the environment GUID (PPAC).
Supports wildcards, but has to match a single environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Instructs the cmdlet to proceed with removing the environment.

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

### -WaitForCompletion
Instructs the cmdlet to wait until the environment has been removed from the tenant.

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

### -DeletionTimeoutMinutes
Maximum number of minutes to wait for the environment to be removed.

Prevents endless waiting when the removal is stuck or has failed.

Is only used together with the -WaitForCompletion parameter.

Defaults to 60 minutes.
Valid range is 1 to 720 minutes.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 60
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
Author: Stefan Vestergaard

## RELATED LINKS
