---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-UdeConfig

## SYNOPSIS
Sets UDE configuration for a specific environment.

## SYNTAX

```
Set-UdeConfig [-EnvironmentUri] <String> [-PackagesVersion] <String> [-Path] <String>
 [[-FallbackPath] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function allows you to set the UDE configuration used in Visual Studio for a specific environment.

## EXAMPLES

### EXAMPLE 1
```
Set-UdeConfig -EnvironmentUri "https://env-123.cloud.dynamics.com" -PackagesVersion "10.0.2177.188" -Path "C:\CustomSourceCode"
```

This will set the UDE configuration for the environment with the URI "https://env-123.cloud.dynamics.com".
It will use the packages version "10.0.2177.188".
It will include the custom source code from "C:\CustomSourceCode".

## PARAMETERS

### -EnvironmentUri
The URI of the environment to configure.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvUri

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PackagesVersion
The version of the packages to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacProvApp

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
The path to the custom source code to include in the UDE configuration.

```yaml
Type: String
Parameter Sets: (All)
Aliases: SourceCode

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FallbackPath
The fallback path to use if the needed packages or XRef DB files are not referenced in any other UDE configuration.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: C:\Temp\d365bap.tools\UdeDeveloperFiles
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
