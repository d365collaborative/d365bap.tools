---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-PpacD365PlatformUpdate

## SYNOPSIS
Start D365 Platform update.

## SYNTAX

```
Invoke-PpacD365PlatformUpdate [-EnvironmentId] <String> [-Version] <Version> [<CommonParameters>]
```

## DESCRIPTION
Invokes the D365 Platform update process for a given environment and version.

## EXAMPLES

### EXAMPLE 1
```
Invoke-PpacD365PlatformUpdate -EnvironmentId "env-123" -Version "10.0.45.4"
```

This will queue the update/install of D365 Platform version 10.0.45.4 for the specified environment.

### EXAMPLE 2
```
Get-PpacD365PlatformUpdate -EnvironmentId "env-123" -Latest | Invoke-PpacD365PlatformUpdate
```

This will get the latest available D365 Platform version for the specified environment.
It will then queue the update/install of that version for the specified environment.

### EXAMPLE 3
```
Get-PpacD365PlatformUpdate -EnvironmentId "env-123" -Oldest | Invoke-PpacD365PlatformUpdate
```

This will get the oldest available D365 Platform version for the specified environment.
It will then queue the update/install of that version for the specified environment.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Version
The version of the D365 Platform to update/install.

```yaml
Type: Version
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
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
