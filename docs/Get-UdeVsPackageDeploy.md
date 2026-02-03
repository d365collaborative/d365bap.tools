---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeVsPackageDeploy

## SYNOPSIS
Get UDE VS package deploys.

## SYNTAX

```
Get-UdeVsPackageDeploy [-All] [-OpenFolder] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Gets the UDE package deploys from Visual Studio, that are stored in the local temp folder.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeVsPackageDeploy
```

This will retrieve the latest UDE VS package deploy from the local temp folder.

### EXAMPLE 2
```
Get-UdeVsPackageDeploy -All
```

This will retrieve all UDE VS package deploys from the local temp folder.

### EXAMPLE 3
```
Get-UdeVsPackageDeploy -OpenFolder
```

This will open the folder containing the UDE VS package deploys in File Explorer.

## PARAMETERS

### -All
Instructs the cmdlet to return all package deploys.

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

### -OpenFolder
Instructs the cmdlet to open the folder containing the package deploys.

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
