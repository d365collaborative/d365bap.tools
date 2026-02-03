---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Export-BapEnvironmentSolution

## SYNOPSIS
Export PowerPlatform / Dataverse Solution from the environment

## SYNTAX

```
Export-BapEnvironmentSolution [-EnvironmentId] <String> [-SolutionId] <String> [-Path] <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to export solutions, on a given environment

The cmdlet downloads the solution, extracts it and removes unnecessary  files

## EXAMPLES

### EXAMPLE 1
```
Export-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -SolutionId 3ac10775-0808-42e0-bd23-83b6c714972f -Path "C:\Temp\"
```

This will export the solution from the environment.
It will extract the files into the "C:\Temp\" location.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

This can be obtained from the Get-BapEnvironment cmdlet

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

### -SolutionId
The id of the solution that you want to work against

This can be obtained from the Get-BapEnvironmentSolution cmdlet

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Path to the location that you want the files to be exported to

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
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
