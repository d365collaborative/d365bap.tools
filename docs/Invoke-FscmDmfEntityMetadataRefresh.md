---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-FscmDmfEntityMetadataRefresh

## SYNOPSIS
Refresh all Data Management Framework entity metadata in a Finance and Operations environment.

## SYNTAX

```
Invoke-FscmDmfEntityMetadataRefresh [-EnvironmentId] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Invokes the InitializeDataManagement OData action on the DataManagementDefinitionGroups entity, which refreshes all Data Management Framework (DMF) entities in the Finance and Operations environment.

## EXAMPLES

### EXAMPLE 1
```
Invoke-FscmDmfEntityMetadataRefresh -EnvironmentId "ContosoEnv"
```

This command refreshes all DMF entity metadata in the environment "ContosoEnv".

## PARAMETERS

### -EnvironmentId
The ID of the environment to refresh DMF entity metadata in.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
