---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-BapInstallAzCli

## SYNOPSIS
Installs Azure CLI by downloading the MSI from the official Microsoft URL.

## SYNTAX

```
Invoke-BapInstallAzCli [[-Url] <String>] [[-Quiet] <Boolean>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function downloads and installs Azure CLI (az), a command-line tool for managing Azure resources.

## EXAMPLES

### EXAMPLE 1
```
Invoke-BapInstallAzCli
```

This will download and install Azure CLI silently.

## PARAMETERS

### -Url
The URL to download Azure CLI from.
Defaults to the official Microsoft URL.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Https://aka.ms/installazurecliwindowsx64
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quiet
Install Azure CLI silently (/quiet /norestart).
Enabled by default, pass -Quiet:$false for an interactive install.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: True
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
