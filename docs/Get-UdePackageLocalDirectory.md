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
Finds installed package folders under the local Dynamics 365 developer folder

Returns the full PackagesLocalDirectory path for each match, sorted ascending

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

Lists matching PackagesLocalDirectory paths.
Wildcards are supported.

### EXAMPLE 3
```
Get-UdePackageLocalDirectory -AsExcelOutput
```

Lists all local PackagesLocalDirectory paths into an Excel file.

## PARAMETERS

### -Version
Packages version to include.
Supports wildcards.

Default: '*'.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### D365Bap.Tools.UdePackageLocalDirectory
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
