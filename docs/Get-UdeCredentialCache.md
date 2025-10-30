---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeCredentialCache

## SYNOPSIS
Gets UDE credential cache information.

## SYNTAX

```
Get-UdeCredentialCache [[-Path] <String>] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves cached UDE credentials stored in an encrypted file used by the CRM Developer Toolkit.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeCredentialCache
```

This will retrieve the UDE credential cache information.

### EXAMPLE 2
```
Get-UdeCredentialCache -AsExcelOutput
```

This will retrieve the UDE credential cache information and export it to an Excel file.

## PARAMETERS

### -Path
The path to the CRM Developer Toolkit folder.

Defaults to the standard location in the user's AppData folder.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: "$env:APPDATA\Microsoft\CRMDeveloperToolKit"
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instruct the cmdlet to output all details directly to an Excel file.

Will include all properties, including those not shown by default in the console output.

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
