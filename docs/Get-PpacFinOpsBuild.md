---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacFinOpsBuild

## SYNOPSIS
Lists quality updates for a FinOps track.

## SYNTAX

```
Get-PpacFinOpsBuild [[-AppVersion] <String>] [-Latest] [[-EnvironmentId] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Queries the developer tools service for every published build of one application track.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacFinOpsBuild -AppVersion "10.0.49"
```

Lists all builds of the 10.0.49 track.

### EXAMPLE 2
```
Get-PpacFinOpsVersion -Latest | Get-PpacFinOpsBuild -Latest
```

Lists the newest build of the newest track.

### EXAMPLE 3
```
Get-PpacFinOpsBuild -AsExcelOutput
```

Lists all builds of the newest track into an Excel file.

## PARAMETERS

### -AppVersion
Track to list as version, build or full build.
Omitted: newest track.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Latest
Returns only the newest build.

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

### -EnvironmentId
Environment for the auth context only.
Omitted: first FinOps environment is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: False
Position: 2
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
