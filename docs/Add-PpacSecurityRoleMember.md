---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacSecurityRoleMember

## SYNOPSIS
Add user to a security role in the Power Platform environment.

## SYNTAX

```
Add-PpacSecurityRoleMember [-EnvironmentId] <String> [-Upn] <String> [-Role] <String[]>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to add an user to a security role in the Power Platform environment.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacSecurityRoleMember -EnvironmentId "env-123" -Upn "alice@contoso.com" -Role "System Administrator"
```

This will add the user with the UPN "alice@contoso.com" to the "System Administrator" security role.

### EXAMPLE 2
```
Add-PpacSecurityRoleMember -EnvironmentId "env-123" -Upn "alice@contoso.com" -Role "System Administrator", "System Customizer"
```

This will add the user with the UPN "alice@contoso.com" to the "System Administrator" and "System Customizer" security roles.

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

### -Upn
The UPN of the user you want to add to the security role in the Power Platform environment.

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
The name of the security role(s) you want to add the user to in the Power Platform environment.

Supports single or multiple role names.

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
