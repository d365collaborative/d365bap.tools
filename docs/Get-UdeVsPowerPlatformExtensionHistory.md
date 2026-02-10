---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeVsPowerPlatformExtensionHistory

## SYNOPSIS
Get UDE VS Power Platform extension history.

## SYNTAX

```
Get-UdeVsPowerPlatformExtensionHistory [-All] [-OpenFolder] [-DeploysOnly] [<CommonParameters>]
```

## DESCRIPTION
Gets the UDE VS Power Platform extension history from the local logs folder.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeVsPowerPlatformExtensionHistory
```

This will retrieve the latest UDE VS Power Platform extension history entry from the local logs folder.

### EXAMPLE 2
```
Get-UdeVsPowerPlatformExtensionHistory -All
```

This will retrieve all UDE VS Power Platform extension history entries from the local logs folder.

### EXAMPLE 3
```
Get-UdeVsPowerPlatformExtensionHistory -OpenFolder
```

This will open the folder containing the UDE VS Power Platform extension history logs in File Explorer.

### EXAMPLE 4
```
Get-UdeVsPowerPlatformExtensionHistory -DeploysOnly
```

This will retrieve only UDE VS Power Platform extension history entries related to deployments from the local logs folder.

## PARAMETERS

### -All
Instructs the cmdlet to return all extension history entries.

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
Instructs the cmdlet to open the folder containing the extension history logs.

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

### -DeploysOnly
Instructs the cmdlet to return only extension history entries related to deployments.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
