---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeDeveloperFile

## SYNOPSIS
Gets UDE developer files for a specified environment.

## SYNTAX

```
Get-UdeDeveloperFile [-EnvironmentId] <String> [[-Path] <String>] [[-Files] <String[]>] [-Download]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves UDE developer files for a specified environment.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeDeveloperFile -EnvironmentId "env-123"
```

This will retrieve the UDE developer files for the specified environment ID without downloading them.

### EXAMPLE 2
```
Get-UdeDeveloperFile -EnvironmentId "env-123" -Download
```

This will download the UDE developer files for the specified environment ID to the default path.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
The path to the directory where the developer files will be saved.

Defaults to "C:\Temp\d365bap.tools\UdeDeveloperFiles".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\Temp\d365bap.tools\UdeDeveloperFiles
Accept pipeline input: False
Accept wildcard characters: False
```

### -Files
The types of developer files to retrieve.

Can be one or more of the following values: "All", "SystemMetadata", "FinOpsVsix22", "TraceParser", "CrossReference".

Defaults to "All".

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: All
Accept pipeline input: False
Accept wildcard characters: False
```

### -Download
Instructs the function to download the developer files to the specified path.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
