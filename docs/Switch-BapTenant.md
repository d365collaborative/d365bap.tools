---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Switch-BapTenant

## SYNOPSIS
Switches the current context to a specified BAP tenant.

## SYNTAX

```
Switch-BapTenant [-Id] <String> [-Force] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function allows you to switch the current context to a specified BAP tenant based on the tenant details stored in the local PSFramework configuration.

It uses the auth provider set with Set-BapToolsAuthProvider: Az PowerShell context (AzAccount) or Azure CLI (AzCli).

## EXAMPLES

### EXAMPLE 1
```
Switch-BapTenant -Id "Contoso"
```

This will switch the current context to the BAP tenant with the id "Contoso".
It will ensure that the authentication token is valid, prompting for re-authentication if necessary.

### EXAMPLE 2
```
Switch-BapTenant -Id "Contoso" -Force
```

This will switch the current context to the BAP tenant with the id "Contoso".
It will force an authentication prompt, even if the current token is still valid.

## PARAMETERS

### -Id
The ID of the BAP tenant to switch to.

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

### -Force
Instruct the function to force an authentication prompt even if the current token is still valid.
This can be useful if you want to ensure that you are using the most up-to-date credentials or if you want to switch to a different user within the same tenant.

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
