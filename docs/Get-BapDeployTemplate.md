---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapDeployTemplate

## SYNOPSIS
Get the available deployment templates for a specific location

## SYNTAX

```
Get-BapDeployTemplate [-Location] <String> [[-Name] <String>] [[-Sku] <String>] [-FnoOnly] [-IncludeDisabled]
 [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the list of available deployment templates for Power Platform environments in a specified location.

Includes details such as template name, SKU, and whether it is disabled.

## EXAMPLES

### EXAMPLE 1
```
Get-BapDeployTemplate -Location "Europe"
```

This will retrieve all available deployment templates for Power Platform environments in the "Europe" location.

### EXAMPLE 2
```
Get-BapDeployTemplate -Location "Europe" -Name "*d365*"
```

This will retrieve all d365 related deployment templates in the "Europe" location.

### EXAMPLE 3
```
Get-BapDeployTemplate -Location "Europe" -Sku "Sandbox"
```

This will retrieve all sandbox deployment templates in the "Europe" location.

### EXAMPLE 4
```
Get-BapDeployTemplate -Location "Europe" -FnoOnly
```

This will retrieve all Finance and Operations related deployment templates in the "Europe" location.

### EXAMPLE 5
```
Get-BapDeployTemplate -Location "Europe" -IncludeDisabled
```

This will retrieve all deployment templates, including disabled ones, in the "Europe" location.

### EXAMPLE 6
```
Get-BapDeployTemplate -Location "Europe" -AsExcelOutput
```

This will retrieve all available deployment templates for Power Platform environments in the "Europe" location and export the output to an Excel file.

## PARAMETERS

### -Location
Specifies the location for which to retrieve deployment templates.

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
Filter the deployment templates by name or ID.

Supports wildcard characters (*).

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

### -Sku
Filter the deployment templates by SKU.
Valid values are "All", "Developer", "Sandbox", "Trial", "SubscriptionBasedTrial", "Production", and "Default".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: All
Accept pipeline input: False
Accept wildcard characters: False
```

### -FnoOnly
Instructs the cmdlet to only return Finance and Operations related templates.

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

### -IncludeDisabled
Instructs the cmdlet to include disabled deployment templates in the output.

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
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
