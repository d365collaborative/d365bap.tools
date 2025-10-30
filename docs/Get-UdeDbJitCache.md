---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeDbJitCache

## SYNOPSIS
Retrieves UDE database JIT access credentials from the local cache.

## SYNTAX

```
Get-UdeDbJitCache [[-Id] <String>] [-ShowPassword] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves UDE database JIT access credentials from the local cache.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeDbJitCache -Id "demo"
```

This will retrieve the JIT database access credentials for the ID "demo".

## PARAMETERS

### -Id
The unique identifier for the JIT access credentials.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Name

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowPassword
Instructs the function to include the password in the output.

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
