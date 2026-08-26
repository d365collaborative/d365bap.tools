---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacEnvironmentGroup

## SYNOPSIS
Retrieves Power Platform environment groups.

## SYNTAX

```
Get-PpacEnvironmentGroup [[-EnvironmentGroup] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves environment groups from the Power Platform API.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacEnvironmentGroup
```

Retrieves all environment groups available to the current tenant.

### EXAMPLE 2
```
Get-PpacEnvironmentGroup -EnvironmentGroup "*Production*"
```

Retrieves environment groups whose ID, display name, or description contains "Production".

### EXAMPLE 3
```
Get-PpacEnvironmentGroup -AsExcelOutput
```

Retrieves all environment groups and exports them to an Excel file.

## PARAMETERS

### -EnvironmentGroup
Filters environment groups by ID, display name, or description.

Supports wildcard characters.

```yaml
Type: String
Parameter Sets: (All)
Aliases: GroupId, GroupName, GroupDescription

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to export the output to an Excel file.

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

### System.Object[]
## NOTES
Author: Florian Hopfner (@FH-Inway)

## RELATED LINKS
