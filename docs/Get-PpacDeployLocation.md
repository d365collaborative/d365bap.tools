---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacDeployLocation

## SYNOPSIS
Get the available deployment locations for Power Platform environments.

## SYNTAX

```
Get-PpacDeployLocation [[-Name] <String>] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the list of available deployment locations where Power Platform environments can be provisioned.

Includes details such as location name and azure regions.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacDeployLocation
```

This will retrieve all available deployment locations for Power Platform environments.

### EXAMPLE 2
```
Get-PpacDeployLocation -Name "Europe"
```

This will retrieve the deployment location "Europe".

### EXAMPLE 3
```
Get-PpacDeployLocation -AsExcelOutput
```

This will retrieve all available deployment locations and export the output to an Excel file.

## PARAMETERS

### -Name
Filter the deployment locations by name or ID.

Supports wildcard characters (*).

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
