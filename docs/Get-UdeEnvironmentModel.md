---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeEnvironmentModel

## SYNOPSIS
Get UDE environment models.

## SYNTAX

```
Get-UdeEnvironmentModel [-EnvironmentId] <String> [[-Name] <String>] [-LatestOnly] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets the currently installed models for a specified environment.

Works against any unified environment (UDE, USE and others).

Installed state is taken from the latest completed msprov_fnopackage
per model.
A latest completed Delete package means the model is not
installed.
The msprov_fnomodule table is only used to enrich the
output when a matching row exists.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeEnvironmentModel -EnvironmentId "env-123"
```

This will retrieve all models for the specified environment id.

### EXAMPLE 2
```
Get-UdeEnvironmentModel -EnvironmentId "env-123" -Name "B"
```

This will retrieve the model named B for the specified environment id.

### EXAMPLE 3
```
Get-UdeEnvironmentModel -EnvironmentId "env-123" -Name "B*" -LatestOnly
```

This will retrieve only the latest model matching B* for the specified environment id.
It is based on the modified date.

### EXAMPLE 4
```
Get-UdeEnvironmentModel -EnvironmentId "env-123" -AsExcelOutput
```

This will retrieve all models for the specified environment id.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
The name of the model that you are looking for.

Supports wildcard patterns.

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

### -LatestOnly
Instructs the cmdlet to return only the latest model.

Is based on the modified date.

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
