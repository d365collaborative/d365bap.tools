---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-FscmUser

## SYNOPSIS
Add a user to a Finance and Operations environment and assign them a security role.

## SYNTAX

```
Add-FscmUser [-EnvironmentId] <String> [-User] <String> [[-Role] <String>] [-RemapExisting]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet adds a user to a Finance and Operations environment and assigns them a security role.
It retrieves the user information from Azure AD / Entra ID based on the provided user identifier, creates or updates the user in the Finance and Operations environment, and assigns the specified security role to the user.

## EXAMPLES

### EXAMPLE 1
```
Add-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe"
```

This command adds the user with the user name "john.doe" to the environment "ContosoEnv".
It will assign the default security role "System user".

### EXAMPLE 2
```
Add-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe" -Role "Sales tax manager"
```

This command adds the user with the user name "john.doe" to the environment "ContosoEnv".
It will assign the security role "Sales tax manager".

### EXAMPLE 3
```
Add-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe" -RemapExisting
```

This command adds the user with the user name "john.doe" to the environment "ContosoEnv".
If a user with the same UserId as "john.doe" already exists in the environment, it will remap the existing user to the new UPN.
It will assign the default security role "System user".

## PARAMETERS

### -EnvironmentId
The ID of the environment to add the user to.

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

### -User
The name or ID of the user to add to the environment.

Can be either the user name, user ID or user principal name (UPN).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
The security role to assign to the user.

Can be either the role name or role ID.
If not specified, the default role "System user" will be assigned.

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

If a user is not found in the Finance and Operations environment based on the UPN, but a user with the same UserId exists, the function will - by default - skip the user.

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
