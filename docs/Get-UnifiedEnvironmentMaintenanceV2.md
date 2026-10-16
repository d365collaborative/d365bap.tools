---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UnifiedEnvironmentMaintenanceV2

## SYNOPSIS
Finance and Operations maintenance settings through the bundled Power Platform SDK.

## SYNTAX

```
Get-UnifiedEnvironmentMaintenanceV2 [-EnvironmentId] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Generated from the bundled Microsoft.PowerPlatform.Management SDK.
Uses the current Az context.
Unspecified update settings retain their current values.

## EXAMPLES

### EXAMPLE 1
```
Get-UnifiedEnvironmentMaintenanceV2 -EnvironmentId 'es-ude-motz-01'
```

Uses the current Az context.

## PARAMETERS

### -EnvironmentId
An exact environment name or Power Platform environment GUID.

```yaml
Type: String
Parameter Sets: (All)
Aliases: EnvironmentName, PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
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

### An object with an EnvironmentId, EnvironmentName, or PpacEnvId property.
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES

## RELATED LINKS
