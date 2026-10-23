---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeEnvironment

## SYNOPSIS
Gets UDE environment details.

## SYNTAX

```
Get-UdeEnvironment [-EnvironmentId] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves details for a Unified Development Environment (UDE).

Currently reports the details from Get-UnifiedEnvironment.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeEnvironment -EnvironmentId "env-123"
```

This will retrieve the UDE environment details for the specified environment ID.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
