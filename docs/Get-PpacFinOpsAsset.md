---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacFinOpsAsset

## SYNOPSIS
Downloads FinOps assets for any build.

## SYNTAX

```
Get-PpacFinOpsAsset [[-AppVersion] <String>] [[-Build] <String>] [[-Asset] <String[]>] [[-Kind] <String>]
 [-Download] [[-Path] <String>] [-Force] [[-EnvironmentId] <String>] [[-OutputPath] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Resolves and downloads NuGet packages, developer files and VHD images.
Any published version can be selected.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacFinOpsAsset -Build "10.0.2790.46"
```

Resolves download URLs for that build.

### EXAMPLE 2
```
Get-PpacFinOpsBuild -Latest | Get-PpacFinOpsAsset -Kind NuGet -Download
```

Downloads all NuGet packages of the newest build.

### EXAMPLE 3
```
Get-PpacFinOpsAsset -Build "10.0.49" -Kind DeveloperFile | Where-Object Asset -eq 'SystemMetadata' | Get-PpacFinOpsAsset -Download
```

Downloads the system metadata of that track.

### EXAMPLE 4
```
Get-PpacFinOpsAsset -Build "10.0.2790.46" -Asset Vhd -Download
```

Downloads the VHD image parts.

### EXAMPLE 5
```
Get-PpacFinOpsAsset -Build "10.0.2790.46" -Kind NuGet -Download -OutputPath "C:\tmp\D365"
```

Downloads NuGet files, extracting under C:\tmp\D365.

## PARAMETERS

### -AppVersion
Track to download as version, track or full build.
Omitted: from -Build, else newest.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Build
Full build, track or short form to download.
Omitted: newest build of the track.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Asset
Names to download; "*" selects everything including VHD.

Default: "*".

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: *
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Kind
Kind to keep: NuGet, DeveloperFile or Vhd.

Default: "*".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: *
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Download
Download the files instead of only resolving URLs.

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

### -Path
Target folder with a subfolder per build.

Default: C:\Temp\d365bap.tools\PpacFinOpsAssets

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: C:\Temp\d365bap.tools\PpacFinOpsAssets
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Re-download files and re-extract folders.

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

### -EnvironmentId
Environment for the auth context only.
Omitted: first FinOps environment is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: False
Position: 6
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -OutputPath
Custom extraction root.
Build and asset folders are appended.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
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
