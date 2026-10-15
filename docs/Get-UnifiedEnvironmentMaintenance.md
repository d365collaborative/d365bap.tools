---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UnifiedEnvironmentMaintenance

## SYNOPSIS
Get maintenance settings for a Unified Environment in Power Platform Admin Center (PPAC).

## SYNTAX

```
Get-UnifiedEnvironmentMaintenance [-EnvironmentId] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves the Finance and Operations maintenance settings for a Unified Environment.

Returns the maintenance window cadence and the preferred days of week for updates.

## EXAMPLES

### EXAMPLE 1
```
Get-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
```

This will retrieve the maintenance settings for the environment "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".

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
