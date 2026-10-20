---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-UnifiedEnvironmentMaintenance

## SYNOPSIS
Set maintenance settings for a Unified Environment in Power Platform Admin Center (PPAC).

## SYNTAX

```
Set-UnifiedEnvironmentMaintenance [-EnvironmentId] <String> [[-Cadence] <String>] [[-DaysOfWeek] <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Updates the Finance and Operations maintenance settings for a Unified Environment.

Supports updating the maintenance window cadence for major version application updates and the preferred days of week for updates.

## EXAMPLES

### EXAMPLE 1
```
Set-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Cadence EveryOtherUpdate
```

This will set the maintenance window cadence to 'EveryOtherUpdate' for the environment "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".

### EXAMPLE 2
```
Set-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -DaysOfWeek Saturday, Sunday
```

This will set the preferred maintenance days to Saturday and Sunday for the environment "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".

### EXAMPLE 3
```
Set-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Cadence EveryUpdate -DaysOfWeek Saturday
```

This will set the maintenance window cadence to 'EveryUpdate' and the preferred maintenance day to Saturday.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

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

### -Cadence
Cadence for major version application updates.

Valid values are:
- "EveryUpdate": Apply every major version application update.
- "EveryOtherUpdate": Apply every other major version application update.
- "Regulated": Regulated cadence for major version application updates.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DaysOfWeek
The preferred days of week for updates.

Valid values are Monday, Tuesday, Wednesday, Thursday, Friday, Saturday and Sunday.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
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
