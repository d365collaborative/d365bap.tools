---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacFinOpsVersion

## SYNOPSIS
Lists all published FinOps versions.

## SYNTAX

### Default (Default)
```
Get-PpacFinOpsVersion [-AppVersion <String>] [-EnvironmentId <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Lowest
```
Get-PpacFinOpsVersion [-AppVersion <String>] [-EnvironmentId <String>] [-Oldest] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Highest
```
Get-PpacFinOpsVersion [-AppVersion <String>] [-EnvironmentId <String>] [-Latest] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries the developer tools service for every published application track.
No target environment is needed.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacFinOpsVersion
```

Lists every published application track.

### EXAMPLE 2
```
Get-PpacFinOpsVersion -AsExcelOutput
```

Lists every published application track into an Excel file.

### EXAMPLE 3
```
Get-PpacFinOpsVersion -Latest
```

Returns only the newest track.

## PARAMETERS

### -AppVersion
Track to show as version, track or full build.
Omitted: everything.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -EnvironmentId
Environment for the auth context only.
Omitted: first FinOps environment is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Oldest
Returns only the oldest version.

```yaml
Type: SwitchParameter
Parameter Sets: Lowest
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Latest
Returns only the latest version.

```yaml
Type: SwitchParameter
Parameter Sets: Highest
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to output the results as an Excel file.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
