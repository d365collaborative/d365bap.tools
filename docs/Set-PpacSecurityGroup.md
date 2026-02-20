---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-PpacSecurityGroup

## SYNOPSIS
Set or remove Security Group for a Power Platform environment

## SYNTAX

```
Set-PpacSecurityGroup [-EnvironmentId] <String> [-SecurityGroup] <String> [-Force]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet allows you to set or remove a Security Group for a Power Platform environment.
It can be used to configure a Security Group to an environment or remove an existing one.

## EXAMPLES

### EXAMPLE 1
```
Set-PpacSecurityGroup -EnvironmentId "ContosoEnv" -SecurityGroup "ContosoAdmins"
```

This command sets the Security Group for the Power Platform environment "ContosoEnv" to "ContosoAdmins".

### EXAMPLE 2
```
Set-PpacSecurityGroup -EnvironmentId "ContosoEnv" -SecurityGroup "" -Force
```

This command removes any existing Security Group linked to the Power Platform environment "ContosoEnv" without additional confirmation.

## PARAMETERS

### -EnvironmentId
The ID of the environment to set or remove the Security Group for.

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
The ID (objectId) or Display Name of the Security Group in Azure AD / Entra ID to link to the environment.

If you want to remove any existing linked Security Group, provide an empty string.

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

### -Force
Instructs the cmdlet to proceed with removing any existing linked Security Group without additional confirmation.

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
