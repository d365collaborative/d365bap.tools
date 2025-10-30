---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Confirm-UdeVs2022Installation

## SYNOPSIS
Confirms the installation of Visual Studio 2022.

## SYNTAX

```
Confirm-UdeVs2022Installation [[-Path] <String>] [-Latest] [<CommonParameters>]
```

## DESCRIPTION
Checks if Visual Studio 2022 is installed on the machine and if the required components are present.

Will prepare necessary files to assist in installing missing components.

## EXAMPLES

### EXAMPLE 1
```
Confirm-UdeVs2022Installation
```

This command checks for the installation of Visual Studio 2022 and prepares prerequisite files in the default path.
Will use the bundled configuration files.

### EXAMPLE 2
```
Confirm-UdeVs2022Installation -Latest
```

This command checks for the installation of Visual Studio 2022 and prepares prerequisite files in the default path.
Will download the latest configuration files from the internet.

## PARAMETERS

### -Path
The path to the directory where prerequisite files will be stored.

Defaults to "C:\Temp\d365bap.tools\Vs2022-Ude-Prerequisites".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: C:\Temp\d365bap.tools\Vs2022-Ude-Prerequisites
Accept pipeline input: False
Accept wildcard characters: False
```

### -Latest
Instructs the function to use the latest configuration files from the internet instead of the bundled ones.

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
