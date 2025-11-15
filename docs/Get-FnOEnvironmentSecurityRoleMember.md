---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FnOEnvironmentSecurityRoleMember

## SYNOPSIS
Get security role members in a Finance and Operations environment.

## SYNTAX

```
Get-FnOEnvironmentSecurityRoleMember [-EnvironmentId] <String> [-Role] <String> [[-UserId] <String>]
 [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to get security role members in a Finance and Operations environment.

## EXAMPLES

### EXAMPLE 1
```
Get-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -Role "*Administrator*"
```

This will list all Security Role Members for the Security Roles matching the "*Administrator*" pattern from the Finance and Operations environment.

### EXAMPLE 2
```
Get-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -Role "-SYSADMIN-" -UserId "john.doe"
```

This will list the Security Role Member with the RoleId "-SYSADMIN-" and UserId "john.doe" from the Finance and Operations environment.

### EXAMPLE 3
```
Get-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -Role "-SYSADMIN-" -AsExcelOutput
```

This will list all Security Role Members for the Security Role with the RoleId "-SYSADMIN-" from the Finance and Operations environment.
Will output all details into an Excel file, that will auto open on your machine.

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

### -Role
Name or RoleId of the security role to filter on.

Supports wildcards.

```yaml
Type: String
Parameter Sets: (All)
Aliases: SecurityRoleId, Name

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserId
UserId of the user that you want to filter on.

Supports wildcards.

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

### -AsExcelOutput
Instruct the cmdlet to output all details directly to an Excel file.

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
