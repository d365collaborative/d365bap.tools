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
This cmdlet retrieves team details from a Power Platform environment.
It allows filtering by team name or ID, and exporting the results to Excel.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacTeam -EnvironmentId "ContosoEnv" -Name "Contoso Team"
```

This command retrieves the team with the name "Contoso Team" from the environment "ContosoEnv" and displays its information in the console.

### EXAMPLE 2
```
Get-PpacTeam -EnvironmentId "ContosoEnv" -Name "*contoso*"
```

This command retrieves all teams with names matching "*contoso*" from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 3
```
Get-PpacTeam -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves all teams from the environment "ContosoEnv".
It will export the information to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve team details from.

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

### -Name
The name or ID of the team to retrieve details for.

Can be either the team name or the team ID.

Supports wildcard characters for flexible matching.

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
Instructs the cmdlet to export the retrieved team information to an Excel file.

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
