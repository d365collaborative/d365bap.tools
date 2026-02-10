---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironment

## SYNOPSIS
Get environment info

## SYNTAX

```
Get-BapEnvironment [[-EnvironmentId] <String>] [-FnoEnabled] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to query and validate all environments that are available from inside PPAC

It utilizes the "https://api.bap.microsoft.com" REST API

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironment
```

This will query for ALL available environments.
It will include both PPAC and FinOps enabled environments.

### EXAMPLE 2
```
Get-BapEnvironment -FnoEnabled
```

This will query for ALL available environments.
It will ONLY include FinOps enabled environments.

### EXAMPLE 3
```
Get-BapEnvironment -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will query for the specific environment.

### EXAMPLE 4
```
Get-BapEnvironment -EnvironmentId *test*
```

This will query for the specific environment, using a wildcard search.

### EXAMPLE 5
```
Get-BapEnvironment -AsExcelOutput
```

This will query for ALL available environments.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

Default value is "*" - which translates into all available environments

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

### -FnoEnabled
Instruct the cmdlet to only return environments that have Finance and Operations enabled

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

### -AsExcelOutput
Instruct the cmdlet to output all details directly to an Excel file

This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state

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
