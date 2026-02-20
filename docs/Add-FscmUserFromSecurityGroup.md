---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-FscmUserFromSecurityGroup

## SYNOPSIS
Enables creation of users from an Entra Security Group in the Dynamics 365 ERP environment.

## SYNTAX

```
Add-FscmUserFromSecurityGroup [-EnvironmentId] <String> [-SecurityGroup] <String> [[-Role] <String>]
 [-RemapExisting] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet creates users in the specified Dynamics 365 ERP environment based on the members of an Entra Security Group.

It will also assign the created users to a specified security role in the Dynamics 365 ERP environment.

## EXAMPLES

### EXAMPLE 1
```
Add-FscmUserFromSecurityGroup -EnvironmentId "env-123" -SecurityGroup "Contoso Sales Team" -Role "Sales Clerk"
```

This will create users in the environment with the id "env-123" based on the members of the Entra Security Group "Contoso Sales Team" and assign them to the "Sales Clerk" security role.
It will validate users based on their UPN, and if a user is not found but a user with the same UserId exists, it will skip the user.

### EXAMPLE 2
```
Add-FscmUserFromSecurityGroup -EnvironmentId "env-123" -SecurityGroup "Contoso Sales Team" -Role "Sales Clerk" -RemapExisting
```

This will create users in the environment with the id "env-123" based on the members of the Entra Security Group "Contoso Sales Team" and assign them to the "Sales Clerk" security role.
It will validate users based on their UPN, and if a user is not found but a user with the same UserId exists, it will remap the existing user to the new UPN and assign the specified security role.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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

### -SecurityGroup
The name or ID of the Entra Security Group from which to create users.

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
The security role to assign to the created users.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: False
Position: 3
Default value: System user
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemapExisting
Instructs the function to remap existing users to the specified security role.

If a user from the Security Group is not found in the Dynamics 365 ERP environment based on the UPN, but a user with the same UserId exists, the function will - by default - skip the user.

If this switch is used, it will remap the existing user to the new UPN and assign the specified security role.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
