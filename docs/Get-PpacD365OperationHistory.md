---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacD365OperationHistory

## SYNOPSIS
Get operation history for a given Unified environment from PPAC.

## SYNTAX

```
Get-PpacD365OperationHistory [-EnvironmentId] <String> [-LatestOnly] [-AsExcelOutput] [-DownloadLog]
 [[-DownloadPath] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the operation history for a specified Unified environment from the Power Platform Admin Center (PPAC).
This includes details such as operation name, description, correlation ID, status, and more.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacD365OperationHistory -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
```

This will fetch the operation history for the specified environment.

### EXAMPLE 2
```
Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -LatestOnly
```

This will fetch only the latest operation from the operation history for the specified environment.

### EXAMPLE 3
```
Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
```

This will fetch the operation history for the specified environment.
It will output the results directly into an Excel file, that will automatically open on your machine.

### EXAMPLE 4
```
Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -DownloadLog
```

This will fetch the operation history for the specified environment.
It will attempt to download the operation logs for each operation in the history, and save them to the default download path.

### EXAMPLE 5
```
Get-PpacD365OperationHistory -EnvironmentId "eec2a-a4c7-4e1d-b8ed-f62acc9c74c6" -DownloadLog -DownloadPath "C:\Temp\MyLogs"
```

This will fetch the operation history for the specified environment.
It will attempt to download the operation logs for each operation in the history, and save them to "C:\Temp\MyLogs".

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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
Instructs the cmdlet to only return the latest operation from the history.

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

### -DownloadLog
Instructs the cmdlet to attempt to download the operation logs for each operation in the history.

Note that not all operations will have logs available, and for some operations (e.g.
FnO DB Sql Jit) there are no logs at all.

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
Specifies the path where the downloaded logs will be saved.

The default path is "C:\Temp\d365bap.tools\PpacD365OperationHistory".

Logs will be organized in subfolders for each environment based on the environment name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\Temp\d365bap.tools\PpacD365OperationHistory
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
