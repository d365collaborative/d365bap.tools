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
This function sets which provider is used to mint access tokens:
AzAccount (default, via the Az.Accounts PowerShell module) or
AzCli (via the Azure CLI, \`az\`).

Switching to AzCli validates the Azure CLI before changing any
configuration.
If the validation fails, the current provider is
left unchanged.

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
Use the Azure CLI (\`az\`) for minting tokens.

Before switching, the function verifies that the \`az\` executable
is available and that it can mint a token for the Power Apps
resource.
If either check fails, the provider is not changed.

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
Use the Az.Accounts PowerShell module for minting tokens.

This is the default provider and requires no validation, as
Az.Accounts is a required module of d365bap.tools.

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
