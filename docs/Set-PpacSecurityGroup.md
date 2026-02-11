---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-PpacSecurityGroup

## SYNOPSIS
Set or remove Security Group linked to environment

## SYNTAX

```
Set-PpacSecurityGroup [-EnvironmentId] <String> [-SecurityGroup] <String> [-Force]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to set or remove a Security Group linked to the environment in Azure AD / Entra ID.

## EXAMPLES

### EXAMPLE 1
```
Set-PpacSecurityGroup -EnvironmentId *uat* -SecurityGroup 12345678-90ab-cdef-1234-567890abcdef
```

This will link the Security Group with SecurityGroup "12345678-90ab-cdef-1234-567890abcdef" to the environment with id containing "uat".

### EXAMPLE 2
```
Set-PpacSecurityGroup -EnvironmentId *uat* -SecurityGroup "My Security Group"
```

This will link the Security Group with Display Name "My Security Group" to the environment with id containing "uat".

### EXAMPLE 3
```
Set-PpacSecurityGroup -EnvironmentId *uat* -SecurityGroup "" -Force
```

This will remove any existing linked Security Group from the environment with id containing "uat".
The cmdlet will not prompt for confirmation because of the -Force switch.

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

### -SecurityGroup
The id (objectId) or Display Name of the Security Group in Azure AD / Entra ID that you want to link to the environment.

If you want to remove any existing linked Security Group, simply provide an empty string.

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
