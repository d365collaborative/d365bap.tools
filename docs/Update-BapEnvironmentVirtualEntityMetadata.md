---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Update-BapEnvironmentVirtualEntityMetadata

## SYNOPSIS
Update the meta data for an Virtual Entity in an environment

## SYNTAX

```
Update-BapEnvironmentVirtualEntityMetadata [-EnvironmentId] <String> [-Name] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to update the metadata for any given Virtual Entity in the environment

This is useful when there has been schema changes on the Virtual Entity inside the D365FO environment, after it was made visible / enabled

## EXAMPLES

### EXAMPLE 1
```
Update-BapEnvironmentVirtualEntityMetadata -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity
```

This will execute the internal mechanism inside the Dataverse environment.
It will halt/stall as long as the operation is running.

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
