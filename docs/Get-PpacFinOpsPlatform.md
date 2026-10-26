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
Get-PpacFinOpsPlatform [[-AppVersion] <String>] [[-Build] <String>] [[-EnvironmentId] <String>]
 [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries the developer tools service for the platform version of one application release.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacFinOpsPlatform -AppVersion "10.0.49"
```

Shows the platform version of the newest 10.0.49 build.

### EXAMPLE 2
```
Get-PpacFinOpsPlatform -Build "10.0.2790.46"
```

Shows the platform version of that build.

### EXAMPLE 3
```
Get-PpacFinOpsBuild -Latest | Get-PpacFinOpsPlatform
```

Shows the platform version of the newest build.

### EXAMPLE 4
```
Get-PpacFinOpsPlatform -Build "10.0.2790.46" -AsExcelOutput
```

Shows the platform version of that build into an Excel file.

## PARAMETERS

### -AppVersion
Track to resolve as version, track or full build.
Omitted: derived from -Build.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Build
Full build, track or short form.
Omitted: newest build of the track.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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
Aliases: PpacEnvId

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
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
