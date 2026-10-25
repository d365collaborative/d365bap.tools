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
Switches the current context to a saved BAP tenant, logging in again when needed.

## EXAMPLES

### EXAMPLE 1
```
Switch-BapTenant -Id "Contoso"
```

Switches to the Contoso tenant, prompting for login when needed.

### EXAMPLE 2
```
Switch-BapTenant -Id "Contoso" -Force
```

Switches to Contoso and always prompts for login.

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
Forces an authentication prompt, even with a valid token.

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
