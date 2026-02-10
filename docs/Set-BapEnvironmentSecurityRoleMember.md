---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapEnvironmentSecurityRoleMember

## SYNOPSIS
Set Security Role members from Entra Group in environment

## SYNTAX

```
Set-BapEnvironmentSecurityRoleMember [-EnvironmentId] <String> [-ObjectId] <String> [-Role] <String>
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to set Security Role members in the Power Platform environment based on members from a Security Group in Azure AD / Entra ID.

## EXAMPLES

### EXAMPLE 1
```
Set-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId 12345678-90ab-cdef-1234-567890abcdef -Role "System Administrator"
```

This will add all members from the Security Group with ObjectId "12345678-90ab-cdef-1234-567890abcdef" to the Security Role "System Administrator" in the environment with id containing "uat".

### EXAMPLE 2
```
Set-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "My Security Group" -Role "Basic User"
```

This will add all members from the Security Group with Display Name "My Security Group" to the Security Role "Basic User" in the environment with id containing "uat".

## PARAMETERS

### -EnvironmentId
Id of the environment that you want to work against.

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
The ObjectId or Display Name of the Security Group in Azure AD / Entra ID that you want to use as source for members to add to the Security Role.

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
The name of the Security Role in the Power Platform environment to which you want to add members from the specified Security Group.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
author: Mötz Jensen (@Splaxi)

## RELATED LINKS
