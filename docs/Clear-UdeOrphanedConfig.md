---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Clear-UdeOrphanedConfig

## SYNOPSIS
Clears orphaned UDE configurations and their associated resources.

## SYNTAX

```
Clear-UdeOrphanedConfig [-Force] [-IncludePackages] [<CommonParameters>]
```

## DESCRIPTION
This function identifies and removes orphaned UDE configurations, including their package directories, symlinks, and XRef databases.

## EXAMPLES

### EXAMPLE 1
```
Clear-UdeOrphanedConfig
```

This will collect all orphaned UDE configurations and display them, but will not proceed with the clearing process.
It will list the XppConfig directories and XRef databases that are considered orphaned.

### EXAMPLE 2
```
Clear-UdeOrphanedConfig -Force
```

This will remove all orphaned UDE configurations and their associated resources.
It will only process the XppConfig directories and XRef databases that are considered orphaned.

### EXAMPLE 3
```
Clear-UdeOrphanedConfig -IncludePackages
```

This will collect all orphaned UDE configurations, including package directories, and display them, but will not proceed with the clearing process.
It will list the package directories, XppConfig directories, and XRef databases that are considered orphaned.

### EXAMPLE 4
```
Clear-UdeOrphanedConfig -IncludePackages -Force
```

This will remove all orphaned UDE configurations and their associated resources, including package directories.
It will process the package directories, XppConfig directories, and XRef databases that are considered orphaned.
Removing package directories might lead to re-downloading packages later on if they are needed for other environments.

## PARAMETERS

### -Force
Instructs the function to proceed with clearing orphaned configurations.

Nothing happens unless this parameter is supplied.

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

### -IncludePackages
Instructs the function to include package directories in the clearing process.

Please note that package directories might be needed for other environments later on, so to avoid downloading packages again, this parameter is optional.

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
