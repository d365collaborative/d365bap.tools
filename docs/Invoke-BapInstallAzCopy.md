---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-BapInstallAzCopy

## SYNOPSIS
Installs AzCopy by downloading it from the official Microsoft URL.

## SYNTAX

```
Invoke-BapInstallAzCopy [[-Url] <String>] [[-Path] <String>] [<CommonParameters>]
```

## DESCRIPTION
This function downloads and installs AzCopy, a command-line tool for copying data to and from Azure storage.

## EXAMPLES

### EXAMPLE 1
```
Invoke-BapInstallAzCopy
```

This will download and install AzCopy to the default path.

## PARAMETERS

### -Url
The URL to download AzCopy from.
Defaults to the official Microsoft URL.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Https://aka.ms/downloadazcopy-v10-windows
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
The local path where AzCopy will be installed.

Defaults to "C:\temp\d365bap.tools\AzCopy\AzCopy.exe".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\temp\d365bap.tools\AzCopy\AzCopy.exe
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
