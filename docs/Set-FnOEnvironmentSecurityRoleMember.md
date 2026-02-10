---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-FnOEnvironmentSecurityRoleMember

## SYNOPSIS
Set security role members in a Finance and Operations environment.

## SYNTAX

```
Set-FnOEnvironmentSecurityRoleMember [-EnvironmentId] <String> [-ObjectId] <String> [-Role] <String>
 [-ImportMissing] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to assign security roles to users in a Finance and Operations environment based on members of an Entra ID (Azure AD) Security Group.

## EXAMPLES

### EXAMPLE 1
```
Set-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "Developers" -Role "-SYSADMIN-"
```

This will assign all members of the Entra ID (Azure AD) Security Group with display name starting with "Developers" to the Security Role with the RoleId "-SYSADMIN-" in the Finance and Operations environment.

### EXAMPLE 2
```
Set-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" -Role "System Administrator"
```

This will assign all members of the Entra ID (Azure AD) Security Group with the ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" to the Security Role with the name "System Administrator" in the Finance and Operations environment.

### EXAMPLE 3
```
Set-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" -Role "System Administrator" -ImportMissing
```

This will assign all members of the Entra ID (Azure AD) Security Group with the ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" to the Security Role with the name "System Administrator" in the Finance and Operations environment.
Will import any missing users from the Entra ID (Azure AD) Security Group into the Finance and Operations environment as Claims Users prior to assigning the security role.

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

### -ObjectId
The ObjectId of the Entra ID (Azure AD) Security Group whose members you want to assign to the security role.

```yaml
Type: String
Parameter Sets: (All)
Aliases: EntraGroup

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
Name or RoleId of the security role to assign the members to.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImportMissing
Instruct the cmdlet to import missing users from the Entra ID (Azure AD) Security Group into the Finance and Operations environment as Claims Users.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
