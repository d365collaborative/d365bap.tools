---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpeSolution

## SYNOPSIS
Get solutions from Power Platform environment.

## SYNTAX

```
Get-PpeSolution [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to query against the solutions from the Power Platform environment.

## EXAMPLES

### EXAMPLE 1
```
Get-PpeSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will fetch all solutions from the environment.

### EXAMPLE 2
```
Get-PpeSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "*invoice*"
```

This will fetch solutions with "invoice" in their name from the environment.

### EXAMPLE 3
```
Get-PpeSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
```

This will fetch all solutions from the environment.
It will then output the results directly into an Excel file.

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
The name of the solution that you are looking for.

The parameter supports wildcards, but will resolve them into a strategy that matches best practice from Microsoft documentation.

It means that you can only have a single search phrase.
E.g.
* -Name "*Retail"
* -Name "Retail*"
* -Name "*Retail*"

It will search in both friendly name, unique name and id of the solution.

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
Instruct the cmdlet to output all details directly to an Excel file.

This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state.

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
