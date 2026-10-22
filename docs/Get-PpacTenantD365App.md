---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacTenantD365App

## SYNOPSIS
Get Dynamics 365 applications available in the tenant.

## SYNTAX

```
Get-PpacTenantD365App [[-Name] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Generated from the bundled Microsoft.PowerPlatform.Management SDK.
Uses the current Az context.
Retrieves all result pages.
Filters application names and unique names, then sorts results by application name.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacTenantD365App
```

Uses the current Az context.

### EXAMPLE 2
```
Get-PpacTenantD365App -Name '*Sales*'
```

Returns applications with Sales in the application name or unique name.

### EXAMPLE 3
```
Get-PpacTenantD365App -Name '*Sales*' -AsExcelOutput
```

Exports matching applications to an Excel workbook.

## PARAMETERS

### -Name
Filter by application name or unique name.
Wildcards are accepted.
Defaults to all applications.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: True
```

### -AsExcelOutput
Export the filtered results to an Excel workbook.

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

### None.
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES

## RELATED LINKS
