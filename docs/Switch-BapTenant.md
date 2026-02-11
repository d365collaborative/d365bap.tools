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
Switch-BapTenant [-Id] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function allows you to switch the current context to a specified BAP tenant based on the tenant details stored in the local PSFramework configuration.

## EXAMPLES

### EXAMPLE 1
```
Switch-BapTenant -Id "Contoso"
```

This will switch the current context to the BAP tenant with the id "Contoso".
It will ensure that the authentication token is valid, prompting for re-authentication if necessary.

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
