---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacTenantProvisioningDefault

## SYNOPSIS
Get the tenant default provisioning language and currency per location.

## SYNTAX

```
Get-PpacTenantProvisioningDefault [[-Location] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves the tenant default language and currency for Power Platform
environment provisioning, resolved live through the bundled Power
Platform SDK.

Tenant defaults are tenant specific and are never served from the
provisioning cache.
One row is returned per matched location.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacTenantProvisioningDefault
```

This will return the tenant default language and currency for all locations.

### EXAMPLE 2
```
Get-PpacTenantProvisioningDefault -Location "europe"
```

This will return the tenant default language and currency for the "europe" location.

### EXAMPLE 3
```
Get-PpacTenantProvisioningDefault -Location "europe*" -AsExcelOutput
```

This will return the tenant default language and currency for matching locations.
It will output the results directly into an Excel file, that will automatically open on your machine.

## PARAMETERS

### -Location
The deployment location to resolve tenant defaults for.

Accepts a location name (e.g.
"europe") or display name (e.g.
"Europe").
Supports wildcard characters (*).
Defaults to all
locations.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
