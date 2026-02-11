---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapTenantDetail

## SYNOPSIS
Gets detailed information about a BAP tenant.

## SYNTAX

```
Get-BapTenantDetail [[-Id] <String>] [[-Upn] <String>] [[-TenantId] <String>] [[-FriendlyName] <String>]
 [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves detailed information about a BAP tenant stored in the local PSFramework configuration.

## EXAMPLES

### EXAMPLE 1
```
Get-BapTenantDetail
```

This will retrieve all available BAP tenant details stored in the local PSFramework configuration.

### EXAMPLE 2
```
Get-BapTenantDetail -Id "Contoso"
This will retrieve the BAP tenant detail for the specified tenant id.
It will only return results where the tenant id matches "Contoso".
```

### EXAMPLE 3
```
Get-BapTenantDetail -Upn "user@contoso.com"
This will retrieve the BAP tenant detail for the specified user principal name (UPN).
It will only return results where the UPN matches "user@contoso.com".
```

### EXAMPLE 4
```
Get-BapTenantDetail -TenantId "12345678-90ab-cdef-1234-567890abcdef"
This will retrieve the BAP tenant detail for the specified tenant id.
It will only return results where the tenant id matches "12345678-90ab-cdef-1234-567890abcdef".
```

### EXAMPLE 5
```
Get-BapTenantDetail -FriendlyName "Contoso"
This will retrieve the BAP tenant detail for the specified friendly name.
It will only return results where the friendly name matches "Contoso".
```

### EXAMPLE 6
```
Get-BapTenantDetail -AsExcelOutput
```

This will export the retrieved BAP tenant details to an Excel file.

## PARAMETERS

### -Id
The id of the registered tenant.

Used to have user defined name for tenants.

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

### -Upn
The User Principal Name (UPN) of the user.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Username, User, Login

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantId
The unique identifier of the tenant.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -FriendlyName
The friendly name of the tenant.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
