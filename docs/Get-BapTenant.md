---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapTenant

## SYNOPSIS
Retrieves information about the available azure tenant.

## SYNTAX

```
Get-BapTenant [[-Upn] <String>] [[-TenantId] <String>] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves information about the available azure tenants based on cached credentials in the local Azure PowerShell context.

## EXAMPLES

### EXAMPLE 1
```
Get-BapTenant
```

This will retrieve all available tenants based on cached Azure PowerShell credentials.

### EXAMPLE 2
```
Get-BapTenant -Upn "alex@contoso.com"
```

This will retrieve the tenant information for the specified UPN.
It will only return results where the UPN matches "alex@contoso.com".

### EXAMPLE 3
```
Get-BapTenant -TenantId "12345678-90ab-cdef-1234-567890abcdef"
```

This will retrieve the tenant information for the specified Tenant ID.
It will only return results where the Tenant ID matches "12345678-90ab-cdef-1234-567890abcdef".

### EXAMPLE 4
```
Get-BapTenant -AsExcelOutput
```

This will export the retrieved tenant information to an Excel file.

## PARAMETERS

### -Upn
Specifies the User Principal Name (UPN) of the user account to filter the results.

Supports wildcard patterns.

Defaults to "*" which means all UPNs.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Username, User, Login

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantId
Specifies the Tenant ID to filter the results.

Supports wildcard patterns.

Defaults to "*" which means all Tenant IDs.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
