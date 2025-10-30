---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapTenantDetail

## SYNOPSIS
Sets the details for a specific tenant.

## SYNTAX

```
Set-BapTenantDetail [-Id] <String> [-Upn] <String> [-TenantId] <String> [[-TenantName] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
This function allows you to set the details for a specific tenant, including the user principal name (UPN), tenant ID, and tenant name.

It enables you to switch between different tenants easily.

## EXAMPLES

### EXAMPLE 1
```
Set-BapTenantDetail -Id "Contoso" -Upn "user@contoso.com" -TenantId "12345678-1234-1234-1234-123456789012" -TenantName "ContosoUnlimited"
```

This will set the details for the tenant with the id "Contoso".
It will associate the UPN "user@contoso.com" with the tenant.
It will also set the tenant ID to "12345678-1234-1234-1234-123456789012" and the friendly name to "ContosoUnlimited".

### EXAMPLE 2
```
Get-BapTenant -TenantId "12345678-1234-1234-1234-123456789012" | Set-BapTenantDetail -Id "Contoso"
```

This will retrieve the tenant with the specified tenant ID.
It will then set the details for the tenant with the id "Contoso" using the retrieved UPN and tenant ID.

## PARAMETERS

### -Id
The id of the registered tenant.

Used to have user defined name for tenants.

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

### -Upn
The user principal name (UPN) of the tenant.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Username, User, Login

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -TenantId
The unique identifier for the tenant.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -TenantName
The friendly name of the tenant.

```yaml
Type: String
Parameter Sets: (All)
Aliases: FriendlyName

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
