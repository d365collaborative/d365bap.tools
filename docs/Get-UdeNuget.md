---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeNuget

## SYNOPSIS
Gets UDE NuGet packages.

## SYNTAX

```
Get-UdeNuget [-EnvironmentId] <String> [[-Path] <String>] [[-Packages] <String[]>] [-Download]
 [-ClearNugetPackages] [[-OutputPath] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves UDE NuGet files for an environment via the DeveloperTools service.

Compatibility wrapper around Get-PpacFinOpsAsset; prefer that command.

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

Downloads only CompilerPackage and Platform.

### EXAMPLE 4
```
Get-UdeNuget -EnvironmentId "env-123" -Download -ClearNugetPackages
```

Downloads and re-extracts everything.

### EXAMPLE 5
```
Get-UdeNuget -EnvironmentId "env-123" -Download -OutputPath "C:\tmp\D365"
```

Downloads and extracts under C:\tmp\D365.

## PARAMETERS

### -EnvironmentId
Environment name, GUID, or wildcard pattern to work against.

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
Folder where the NuGet files are downloaded.

Default: C:\Temp\d365bap.tools\UdeNugets

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
Types to retrieve.
All selects every package.

Default: All

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
Re-download and re-extract packages via Get-PpacFinOpsAsset -Force.

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

### -OutputPath
Custom extraction root.
Build and NuGets folders are appended.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
