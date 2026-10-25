---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapToolsAuthProvider

## SYNOPSIS
Sets the token minting provider used by d365bap.tools.

## SYNTAX

### AzAccount (Default)
```
Set-BapToolsAuthProvider [-AzAccount] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### AzCli
```
Set-BapToolsAuthProvider [-AzCli] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Sets which provider mints access tokens.
Switching validates first and keeps the current provider on failure.

## EXAMPLES

### EXAMPLE 1
```
Set-BapToolsAuthProvider -AzAccount
```

This will set the token minting provider to AzAccount.

### EXAMPLE 2
```
Set-BapToolsAuthProvider -AzCli
```

This will validate the Azure CLI installation and its login
state, then set the token minting provider to AzCli.

## PARAMETERS

### -AzCli
Use the Azure CLI for minting tokens.

```yaml
Type: SwitchParameter
Parameter Sets: AzCli
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AzAccount
Use the Az.Accounts module for minting tokens.

```yaml
Type: SwitchParameter
Parameter Sets: AzAccount
Aliases:

Required: True
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
