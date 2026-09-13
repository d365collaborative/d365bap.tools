---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-PpacUser

## SYNOPSIS
Remove a user from a Power Platform environment.

## SYNTAX

```
Remove-PpacUser [-EnvironmentId] <String> [-User] <String> [[-Role] <String[]>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes the Dataverse systemuser for a Microsoft Entra ID user.
Optionally only removes one or more security role assignments and keeps the user.

Removal order is enforced by the platform:
all role assignments must be removed first, then the user must be disabled before DELETE.
Users that still exist in Entra ID cannot be hard deleted (0x80048359) - those stay in place as disabled users without roles.

## EXAMPLES

### EXAMPLE 1
```
Remove-PpacUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com"
```

Removes all security roles from megan.bowen@contoso.com, disables the user and deletes it.
When the user still exists in Entra ID it stays as a disabled user without roles.

### EXAMPLE 2
```
Remove-PpacUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com" -Role "System Administrator"
```

Only removes the System Administrator role assignment and keeps the user.

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

### -User
The user that you want to remove from the Power Platform environment.

Can be either the User Principal Name (UPN), mail address or Entra object id.

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

Can be either the role name or the role ID.
When omitted the user is fully removed (all roles, disable, delete).

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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
