---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeXrefDb

## SYNOPSIS
Gets UDE cross-reference databases.

## SYNTAX

```
Get-UdeXrefDb [[-Name] <String>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves UDE cross-reference databases.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeXrefDb
```

This will retrieve all available UDE cross-reference databases.

### EXAMPLE 2
```
Get-UdeXrefDb -Name "db-123*"
```

This will retrieve the UDE cross-reference database with the specified name.

## PARAMETERS

### -Name
The name of the database to retrieve.

Supports wildcard patterns.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### [PsCustomObject]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
