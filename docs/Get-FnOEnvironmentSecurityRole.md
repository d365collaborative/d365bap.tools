---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FnOEnvironmentSecurityRole

## SYNOPSIS
Get security roles in a Finance and Operations environment.

## SYNTAX

```
Get-FnOEnvironmentSecurityRole [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to get security roles in a Finance and Operations environment.

## EXAMPLES

### EXAMPLE 1
```
Get-FnOEnvironmentSecurityRole -EnvironmentId *uat*
```

This will list all Security Roles from the Finance and Operations environment, by the EnvironmentId (Name/Wildcard).

### EXAMPLE 2
```
Get-FnOEnvironmentSecurityRole -EnvironmentId *uat* -Name "*Administrator*"
```

This will list all Security Roles, which matches the "*Administrator*" pattern, from the Finance and Operations environment.

### EXAMPLE 3
```
Get-FnOEnvironmentSecurityRole -EnvironmentId *uat* -Name "-SYSADMIN-"
```

This will list the Security Role with the RoleId "-SYSADMIN-" from the Finance and Operations environment.

### EXAMPLE 4
```
Get-FnOEnvironmentSecurityRole -EnvironmentId *uat* -AsExcelOutput
```

This will list all Security Roles from the Finance and Operations environment, by the EnvironmentId (Name/Wildcard).
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

### -Name
Name or RoleId of the security role to filter on.

Wildcards are supported.

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
