---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeNuget

## SYNOPSIS
Gets UDE NuGet packages for a specified environment.

## SYNTAX

```
Get-UdeNuget [-EnvironmentId] <String> [[-Path] <String>] [[-Packages] <String[]>] [-Download]
 [-ClearNugetPackages] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves the UDE NuGet packages for a specified environment.

Uses the same DeveloperTools service as the Power Platform Tools for Visual Studio extension.

The NuGet packages were previously available from LCS, and are now served from developertools.powerplatform.microsoft.com.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeNuget -EnvironmentId "env-123"
```

This will retrieve the UDE NuGet packages for the specified environment ID without downloading them.

### EXAMPLE 2
```
Get-UdeNuget -EnvironmentId "env-123" -Download
```

This will download the UDE NuGet packages for the specified environment ID to the default path.

### EXAMPLE 3
```
Get-UdeNuget -EnvironmentId "env-123" -Download -Packages "CompilerPackage","Platform"
```

This will download only the CompilerPackage and Platform UDE NuGet packages for the specified environment ID to the default path.

### EXAMPLE 4
```
Get-UdeNuget -EnvironmentId "env-123" -Download -ClearNugetPackages
```

This will download the UDE NuGet packages for the specified environment ID to the default path.
It will clear the existing extracted NuGet packages before extracting, ensuring a clean state for the extraction.

## PARAMETERS

### -EnvironmentId
The ID of the environment that you want to work against.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

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

### -Path
The path to the directory where the NuGet packages will be saved.

Defaults to "C:\Temp\d365bap.tools\UdeNugets".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\Temp\d365bap.tools\UdeNugets
Accept pipeline input: False
Accept wildcard characters: False
```

### -Packages
The types of NuGet packages to retrieve.

Can be one or more of the following values: "All", "CompilerPackage", "Platform", "ApplicationSuite", "Application1", "Application2".

Defaults to "All".

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: All
Accept pipeline input: False
Accept wildcard characters: False
```

### -Download
Instructs the function to download the NuGet packages to the specified path.

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

### -ClearNugetPackages
Instructs the function to clear the existing extracted NuGet packages before extracting.

Use with caution as it will delete existing files.

Can be useful when the extraction has failed previously and you want to ensure a clean state for the extraction.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
