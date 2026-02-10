---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacD365PlatformUpdate

## SYNOPSIS
Get D365 platform update information for the environment.

## SYNTAX

### Default (Default)
```
Get-PpacD365PlatformUpdate -EnvironmentId <String> [<CommonParameters>]
```

### Lowest
```
Get-PpacD365PlatformUpdate -EnvironmentId <String> [-Oldest] [<CommonParameters>]
```

### Highest
```
Get-PpacD365PlatformUpdate -EnvironmentId <String> [-Latest] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to retrieve information about the available D365 platform updates for the environment.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacD365PlatformUpdate -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
```

This will retrieve all available D365 platform updates for the environment.

### EXAMPLE 2
```
Get-PpacD365PlatformUpdate -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Oldest
```

This will retrieve the oldest available D365 platform update for the environment.

### EXAMPLE 3
```
Get-PpacD365PlatformUpdate -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Latest
```

This will retrieve the latest available D365 platform update for the environment.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Oldest
Instructs the cmdlet to return only the oldest available platform update for the environment.

```yaml
Type: SwitchParameter
Parameter Sets: Lowest
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Latest
Instructs the cmdlet to return only the latest available platform update for the environment.

```yaml
Type: SwitchParameter
Parameter Sets: Highest
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
