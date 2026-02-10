---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-UdeEnvironmentInSession

## SYNOPSIS
Sets the UDE environment in the current PowerShell session.

## SYNTAX

```
Set-UdeEnvironmentInSession [-EnvironmentId] <String> [<CommonParameters>]
```

## DESCRIPTION
This function sets the specified UDE environment in the current PowerShell session by updating the default parameter values for relevant cmdlets.

## EXAMPLES

### EXAMPLE 1
```
Set-UdeEnvironmentInSession -EnvironmentId "env-123"
```

This will set the specified environment ID in the current PowerShell session.

### EXAMPLE 2
```
Get-UdeEnvironment -EnvironmentId "env-123" | Set-UdeEnvironmentInSession
```

This will set the environment ID from the piped UDE environment object in the current PowerShell session.

## PARAMETERS

### -EnvironmentId
The ID of the environment that you want to work against.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
