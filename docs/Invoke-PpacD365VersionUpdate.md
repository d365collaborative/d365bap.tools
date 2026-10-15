---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-PpacD365VersionUpdate

## SYNOPSIS
Apply a D365 Finance and Operations version to the environment.

## SYNTAX

```
Invoke-PpacD365VersionUpdate [-EnvironmentId] <String> [-Version] <Version> [-WaitForCompletion]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Applies the specified D365 Finance and Operations application version to the environment.

## EXAMPLES

### EXAMPLE 1
```
Invoke-PpacD365VersionUpdate -EnvironmentId "env-123" -Version "10.0.47.5"
```

This will queue the update to D365 Finance and Operations version 10.0.47.5 for the specified environment.
It returns immediately with the operationId / resourceId.

### EXAMPLE 2
```
Invoke-PpacD365VersionUpdate -EnvironmentId "env-123" -Version "10.0.47.5" -WaitForCompletion
```

This will queue the update to D365 Finance and Operations version 10.0.47.5 for the specified environment.
It will poll the operation status every 60 seconds until it succeeds or fails.

### EXAMPLE 3
```
Get-PpacD365Version -EnvironmentId "env-123" -Latest | Invoke-PpacD365VersionUpdate
```

This will get the latest available D365 Finance and Operations version for the specified environment.
It will then queue the update to that version for the specified environment.

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
The version of D365 Finance and Operations to apply.

A full application version is expected (e.g.
"10.0.47.5"), but a short platform
version (e.g.
"10.0.47") is also accepted.

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

### -WaitForCompletion
Instructs the cmdlet to wait until the apply operation reaches a terminal state.

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
