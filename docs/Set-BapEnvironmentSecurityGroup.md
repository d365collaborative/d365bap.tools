---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapEnvironmentSecurityGroup

## SYNOPSIS
Set or remove Security Group linked to environment

## SYNTAX

```
Set-BapEnvironmentSecurityGroup [-EnvironmentId] <String> [-ObjectId] <String> [-Force] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to set or remove a Security Group linked to the environment in Azure AD / Entra ID.

## EXAMPLES

### EXAMPLE 1
```
Set-BapEnvironmentSecurityGroup -EnvironmentId *uat* -ObjectId 12345678-90ab-cdef-1234-567890abcdef
```

This will link the Security Group with ObjectId "12345678-90ab-cdef-1234-567890abcdef" to the environment with id containing "uat".

### EXAMPLE 2
```
Set-BapEnvironmentSecurityGroup -EnvironmentId *uat* -ObjectId "My Security Group"
```

This will link the Security Group with Display Name "My Security Group" to the environment with id containing "uat".

### EXAMPLE 3
```
Set-BapEnvironmentSecurityGroup -EnvironmentId *uat* -ObjectId "" -Force
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

### -ObjectId
The ObjectId or Display Name of the Security Group in Azure AD / Entra ID that you want to link to the environment.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
