---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-FscmUser

## SYNOPSIS
Enables or disables a user in a Finance and Operations environment.

## SYNTAX

```
Set-FscmUser [-EnvironmentId] <String> [-User] <String[]> [-State] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function enables or disables a user in a Finance and Operations environment by calling the appropriate API in the environment.

The user can be specified by their UPN, alias, email, name or UserId in the environment.

## EXAMPLES

### EXAMPLE 1
```
Set-FscmUser -EnvironmentId "env-123" -User "alice@contoso.com" -State Enabled
```

This will enable the user with the UPN "alice@contoso.com" in the specified environment.

### EXAMPLE 2
```
Set-FscmUser -EnvironmentId "env-123" -User "alice" -State Disabled
```

This will disable the user with the UserId "alice" in the specified environment.

### EXAMPLE 3
```
Set-FscmUser -EnvironmentId "env-123" -User "alice","bob" -State Enabled
```

This will enable the users with the UserId "alice" and "bob" in the specified environment.

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
The user(s) to enable or disable in the Finance and Operations environment.

You can specify one or more users by their UPN, alias, email, name or UserId in the environment.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -State
Instructs the function to either enable or disable the specified user(s).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

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
