---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Start-UdeDbSsms

## SYNOPSIS
Starts SQL Server Management Studio (SSMS) with the specified JIT access credentials.

## SYNTAX

```
Start-UdeDbSsms [-Id] <String> [[-Version] <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function starts SQL Server Management Studio (SSMS) and connects to the specified database using the JIT access credentials stored in the local cache.

## EXAMPLES

### EXAMPLE 1
```
Start-UdeDbSsms -Id "demo"
```

This will start SSMS version 20 and connect to the database using the JIT access credentials for the ID "demo".

### EXAMPLE 2
```
Start-UdeDbSsms -Id "demo" -Version 21
```

This will start SSMS version 21 and connect to the database using the JIT access credentials for the ID "demo".

## PARAMETERS

### -Id
The unique identifier for the JIT access credentials.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Version
The version of SSMS to use (20 or 21).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 20
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
You need to have persisted JIT credentials using Set-UdeDbJitCache before using this function.

Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
