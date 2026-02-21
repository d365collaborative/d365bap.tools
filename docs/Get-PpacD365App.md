---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacD365App

## SYNOPSIS
Get D365 application that are available in the environment.

## SYNTAX

```
Get-PpacD365App [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves available D365 applications from the environment as they are shown in the Power Platform Admin Center (PPAC).

## EXAMPLES

### EXAMPLE 1
```
Get-PpacD365App -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
```

This will fetch all D365 applications from the environment.

### EXAMPLE 2
```
Get-PpacD365App -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "*invoice*"
```

This will fetch all D365 applications from the environment.
It will filter the results to only include applications that have "invoice" in either the application name or the unique name.

### EXAMPLE 3
```
Get-PpacD365App -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
```

This will fetch all D365 applications from the environment.
It will output the results directly into an Excel file, that will automatically open on your machine.

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

### -Name
Name of the D365 application that you want to retrieve.

Wildcards are accepted, and it will search in both the application name and the unique name for a match.

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
Instructs the cmdlet to output the results as an Excel file.

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
