---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpacApplicationUser

## SYNOPSIS
Add application user to Power Platform environment.

## SYNTAX

```
Add-PpacApplicationUser [-EnvironmentId] <String> [-ServicePrincipal] <String> [-Role] <String>
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to add an application user to the environment and assign a security role to it.

## EXAMPLES

### EXAMPLE 1
```
Add-PpacApplicationUser -EnvironmentId "env-123" -ObjectId "00000000-0000-0000-0000-000000000000" -Role "System Administrator"
```

This will add an application user to the Power Platform environment.
It will use the Service Principal with the ObjectId "00000000-0000-0000-0000-000000000000" from Azure AD / Entra ID
It will then assign the "System Administrator" security role to it in the Power Platform environment.

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

### -ServicePrincipal
{{ Fill ServicePrincipal Description }}

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
The security role that you want to assign to the application user.

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
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
