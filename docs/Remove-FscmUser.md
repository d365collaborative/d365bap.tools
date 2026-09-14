---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-FscmUser

## SYNOPSIS
Remove a user from a Finance and Operations environment.

## SYNTAX

```
Remove-FscmUser [-EnvironmentId] <String> [-User] <String> [[-Role] <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes the SystemUser record for a Finance and Operations user.
Optionally only removes one or more security role assignments and keeps the user.

Role assignments are removed via DELETE SecurityUserRoles(UserId, SecurityRoleIdentifier), then the user is removed via DELETE SystemUsers(UserID).

## EXAMPLES

### EXAMPLE 1
```
Remove-FscmUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com"
```

Removes all security roles from megan.bowen@contoso.com and deletes the FSCM user.

### EXAMPLE 2
```
Remove-FscmUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com" -Role "System administrator"
```

Only removes the System administrator role assignment and keeps the user.

## PARAMETERS

### -EnvironmentId
The ID of the environment to remove the user from.

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
The name or ID of the user to remove from the environment.

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
Only remove the supplied security role assignment(s) and keep the user.

Can be either the role name or role ID.
When omitted the user is fully removed (all roles, then delete).

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: RoleName

Required: False
Position: 3
Default value: None
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
