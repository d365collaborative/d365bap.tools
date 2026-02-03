---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapEnvironmentVirtualEntity

## SYNOPSIS
Set Virtual Entity configuration in environment

## SYNTAX

```
Set-BapEnvironmentVirtualEntity [-EnvironmentId] <String> [-Name] <String> [-VisibilityOn] [-VisibilityOff]
 [-TrackingOn] [-TrackingOff] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to update the configuration for any given Virtual Entity in the environment

The configuration is done against the Dataverse environment, and allows the user to update the Visibility or TrackingChanges, for a given Virtual Entity

## EXAMPLES

### EXAMPLE 1
```
Set-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity -VisibilityOn -TrackingOff
```

This will enable the Virtual Entity "AccountantEntity" on the environment.
It will turn off the ChangeTracking at the same time.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
AccountantEntity               True      False                 00002893-0000-0000-0003-005001000000

### EXAMPLE 2
```
Set-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity -VisibilityOff
```

This will disable the Virtual Entity "AccountantEntity" on the environment.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
AccountantEntity               False     False                 00002893-0000-0000-0003-005001000000

### EXAMPLE 3
```
Set-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity -TrackingOn
```

This will update the Virtual Entity "AccountantEntity" on the environment.
It will enable the ChangeTracking for the entity.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
AccountantEntity               True      True                  00002893-0000-0000-0003-005001000000

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

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
The name of the virtual entity that you are looking for

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VisibilityOn
Instructs the cmdlet to turn "ON" the Virtual Entity

Can be used in combination with TrackingOn / TrackingOff

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

### -VisibilityOff
Instructs the cmdlet to turn "OFF" the Virtual Entity

Can be used in combination with TrackingOn / TrackingOff

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

### -TrackingOn
Instructs the cmdlet to enable ChangeTracking on the Virtual Entity

Can be used in combination with VisibilityOn / VisibilityOff

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

### -TrackingOff
Instructs the cmdlet to disable ChangeTracking on the Virtual Entity

Can be used in combination with VisibilityOn / VisibilityOff

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
