---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacTeam

## SYNOPSIS
Get team details from Power Platform environment.

## SYNTAX

```
Get-PpacTeam [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to get details about teams in a Power Platform environment.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacTeam -EnvironmentId "env-123" -Name "*Team*"
```

This will retrieve the team with the name "*Team*" in the environment with the id "env-123".

### EXAMPLE 2
```
Get-PpacTeam -EnvironmentId "env-123" -Name "*Team*" -AsExcelOutput
```

This will retrieve the team with the name "*Team*" in the environment with the id "env-123".
It will export the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

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
The name of the team you want to get details for.

Support wildcards (*) to filter the team names.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the function to export the results to an Excel file.

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
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
