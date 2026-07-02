---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Export-UdeModelLabel

## SYNOPSIS
Exports UDE model label files from PackagesLocalDirectory

## SYNTAX

### Active (Default)
```
Export-UdeModelLabel [-Model <String[]>] [-Language <String>] [-LabelFileId <String>] [-OutputPath <String>]
 [-AsExcelOutput] [-ShowLabelDetails] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Pipeline
```
Export-UdeModelLabel [-Model <String[]>] [-Language <String>] [-LabelFileId <String>] [-OutputPath <String>]
 [-AsExcelOutput] [-ShowLabelDetails] [-PackagesLocalDirectory <String[]>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Copies label files from the local packages into a versioned folder structure under the output path

Uses the active UDE configuration by default, or accepts PackagesLocalDirectory from Get-UdePackageLocalDirectory via the pipeline

## EXAMPLES

### EXAMPLE 1
```
Export-UdeModelLabel
```

Exports label files from the active UDE configuration.
It will export all label files for all models.
It will export the default language 'en-US'.

### EXAMPLE 2
```
Export-UdeModelLabel -Model 'Foundation'
```

Exports matching labels from the active UDE configuration.
It will export all label files for the 'Foundation' model.
It will export the default language 'en-US'.

### EXAMPLE 3
```
Export-UdeModelLabel -Model 'Foundation' -LabelFileId 'AccountsPayable'
```

Exports matching labels from the active UDE configuration.
It will export only label files for the 'Foundation' model.
It will export only the label file with the id 'AccountsPayable'.
It will export the default language 'en-US'.

### EXAMPLE 4
```
Get-UdePackageLocalDirectory -Version '10.0.2345*' | Export-UdeModelLabel
```

Exports label files for all matching local package versions.
It will export all label files for all models.
It will export the default language 'en-US'.

## PARAMETERS

### -Model
Module name(s) to include.
Supports wildcards.
Defaults to '*'

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @('*')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Language
Language code used to resolve the label descriptor files.
Defaults to 'en-US'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: En-US
Accept pipeline input: False
Accept wildcard characters: False
```

### -LabelFileId
Label file id(s) to include.
Supports wildcards.
Defaults to '*'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
Root folder for exported labels.
Each packages version is exported to a subfolder

Defaults to 'C:\temp\d365bap.tools\ModelLabels'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: C:\temp\d365bap.tools\ModelLabels
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

### -ShowLabelDetails
Instructs the cmdlet to display the processed label details

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

### -PackagesLocalDirectory
One or more PackagesLocalDirectory paths to export from.
Supports pipeline input

```yaml
Type: String[]
Parameter Sets: Pipeline
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
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

### D365Bap.Tools.UdeModelLabel
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
