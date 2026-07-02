---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdePackageLocalDirectory

## SYNOPSIS
Gets local UDE PackagesLocalDirectory paths

## SYNTAX

```
Get-UdePackageLocalDirectory [[-Version] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Finds installed packages versions under the local Dynamics 365 developer folder

Returns the full PackagesLocalDirectory path for each matching version, sorted ascending by version

## EXAMPLES

### EXAMPLE 1
```
Get-UdePackageLocalDirectory
```

Lists all local PackagesLocalDirectory paths.
It will only include versions where PackagesLocalDirectory exists.

### EXAMPLE 2
```
Get-UdePackageLocalDirectory -Version '10.0.2345*'
```

Lists PackagesLocalDirectory paths for matching package versions.
It will support wildcard search on the version number.

### EXAMPLE 3
```
Get-UdePackageLocalDirectory -AsExcelOutput
```

Lists all local PackagesLocalDirectory paths.
It will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -Version
Packages version to include.
Supports wildcards.
Defaults to '*'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instruct the cmdlet to output all details directly to an Excel file

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

### D365Bap.Tools.UdePackageLocalDirectory
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
