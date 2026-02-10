---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Clear-UdeDbJitCache

## SYNOPSIS
Clears the JIT cache for the UDE database.

## SYNTAX

```
Clear-UdeDbJitCache [-Force] [<CommonParameters>]
```

## DESCRIPTION
This function clears the Just-In-Time (JIT) cache for the UDE database by removing expired credentials and resetting the cache configuration.

## EXAMPLES

### EXAMPLE 1
```
Clear-UdeDbJitCache
```

This will clear all expired JIT database access credentials from the local cache.

### EXAMPLE 2
```
Clear-UdeDbJitCache -Force
```

This will clear all JIT database access credentials from the local cache, regardless of their expiration status.

## PARAMETERS

### -Force
Instructs the function to clear all cached JIT credentials regardless of their expiration status.

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
