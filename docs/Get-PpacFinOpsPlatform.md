---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacFinOpsPlatform

## SYNOPSIS
Resolves the platform version of a build.

## SYNTAX

```
Get-PpacFinOpsPlatform [-Build] <String> [[-EnvironmentId] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Queries the developer tools service for the platform version of one application release.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacFinOpsPlatform -Build "10.0.2790.46"
```

Shows the platform version of that build.

### EXAMPLE 2
```
Get-PpacFinOpsBuild -Latest | Get-PpacFinOpsPlatform
```

Shows the platform version of the newest build.

## PARAMETERS

### -Build
Full build, track or application version.
Short forms resolve to the newest build.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -EnvironmentId
Environment for the auth context only.
Omitted: first FinOps environment is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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
