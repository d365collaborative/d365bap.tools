---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Clear-UdeCredentialCache

## SYNOPSIS
Clears the cached credentials used by Visual Studio for connecting to Dynamics 365 / Power Platform environments.

## SYNTAX

```
Clear-UdeCredentialCache [-Force] [<CommonParameters>]
```

## DESCRIPTION
Clears the cached credentials used by Visual Studio for connecting to Dynamics 365 / Power Platform environments by removing the credential cache directory located at %APPDATA%\Microsoft\CRMDeveloperToolKit.

## EXAMPLES

### EXAMPLE 1
```
Clear-UdeCredentialCache
```

This will prompt the user to make sure that they understand what will be removed/cleared.
However, no action will be taken unless the -Force parameter is supplied.

### EXAMPLE 2
```
Clear-UdeCredentialCache -Force
```

This will remove all Visual Studio cached credentials for connecting to Dynamics 365 / Power Platform environments.
Force parameter is needed for the function to proceed.

## PARAMETERS

### -Force
Instructs the function to proceed with clearing the credential cache.

Nothing happens unless this parameter is supplied.

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
