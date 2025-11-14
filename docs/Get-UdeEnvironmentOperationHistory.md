---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeEnvironmentOperationHistory

## SYNOPSIS
Get UDE environment operation history.

## SYNTAX

```
Get-UdeEnvironmentOperationHistory [-EnvironmentId] <String> [-LatestOnly] [-AsExcelOutput] [-DownloadLog]
 [[-DownloadPath] <String>] [<CommonParameters>]
```

## DESCRIPTION
Gets the UDE environment operation history for a specified environment.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123"
```

This will retrieve all UDE environment operation history for the specified environment id.

### EXAMPLE 2
```
Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123" -LatestOnly
```

This will retrieve only the latest UDE environment operation history for the specified environment id.
It is based on the modified date.

### EXAMPLE 3
```
Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123" -AsExcelOutput
```

This will retrieve all UDE environment operation history for the specified environment id.
Will output all details into an Excel file, that will auto open on your machine.

### EXAMPLE 4
```
Get-UdeEnvironmentOperationHistory -EnvironmentId "env-123" -DownloadLog -DownloadPath "C:\Logs"
```

This will retrieve all UDE environment operation history for the specified environment id.
Will download the operation logs into the specified path.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -LatestOnly
Instructs the cmdlet to return only the latest operation history.

Is based on the modified date.

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

### -AsExcelOutput
Instructs the function to export the results to an Excel file.

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

### -DownloadLog
Instructs the function to download the operation log.

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

### -DownloadPath
Specifies the path where the operation log will be downloaded.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\Temp\d365bap.tools\UdeEnvironmentOperation
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
