---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacSecurityRoleMember

## SYNOPSIS
Enables assignment of a user to a security role in the Power Platform environment.

## SYNTAX

```
Add-PpacSecurityRoleMember [-EnvironmentId] <String> [-User] <String> [-Role] <String[]>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet assigns a user to one or more security roles in the specified Power Platform environment.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacSecurityRoleMember -EnvironmentId "env-123" -User "alice" -Role "System Customizer"
```

This will assign the user "alice" to the "System Customizer" security role in the environment with the id "env-123".

### EXAMPLE 2
```
Add-PpacSecurityRoleMember -EnvironmentId "env-123" -User "alice@contoso.com" -Role "System Customizer", "Environment Maker"
```

This will assign the user "alice@contoso.com" to the "System Customizer" and "Environment Maker" security roles in the environment with the id "env-123".

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
The user that you want to assign to the security role.

Can be either the User Principal Name (UPN) or the UserId of the user in the Power Platform environment.

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
The security role that you want to assign to the user.

Can be either the role name or the role ID.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: RoleName

Required: True
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
