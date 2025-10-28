---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeConfig

## SYNOPSIS
Gets UDE configuration information.

## SYNTAX

```
Get-UdeConfig [[-Name] <String>] [-Active] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves configuration settings for the User Development Environment (UDE).

Is based on the details that the developer can see from within Visual Studio when working with UDE.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeConfig
```

This will retrieve all available UDE configurations.

### EXAMPLE 2
```
Get-UdeConfig -Name "ContosoUdeConfig"
```

This will retrieve the UDE configuration with the name "ContosoUdeConfig".

### EXAMPLE 3
```
Get-UdeConfig -Active
```

This will retrieve the currently active UDE configuration.

## PARAMETERS

### -Name
The name of the UDE configuration.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -Active
Instructs the function to only return the active UDE configuration.

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
Instruct the cmdlet to output all details directly to an Excel file.

Will include all properties, including those not shown by default in the console output.

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
