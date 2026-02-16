---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-PpePublishAllCustomizations

## SYNOPSIS
Start the publish all customizations process for a given environment.

## SYNTAX

```
Invoke-PpePublishAllCustomizations [-EnvironmentId] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This cmdlet starts the publish all customizations process for a given Power Platform environment.

Can be helpful to run this cmdlet after importing a solution to make sure all customizations are published and ready to use.

## EXAMPLES

### EXAMPLE 1
```
Invoke-PpePublishAllCustomizations -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
```

This will start the publish all customizations process for the environment with the id "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".
It will fail if any internal error occurs during the publish process, otherwise it will complete silently.

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
