---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-UdeDbQuery

## SYNOPSIS
Invokes a SQL query against a UDE database using cached JIT access credentials.

## SYNTAX

```
Invoke-UdeDbQuery [-Id] <String> [-Query] <String> [[-QueryTimeout] <Int32>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function executes a SQL query against the database of a specified environment.

It uses JIT access credentials from the local cache (see Get-UdeDbJitCache) and never
obtains credentials itself.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeDbJit -EnvironmentId "es-ude-motz-01" -Role Reader | Set-UdeDbJitCache -Id "motz01-reader"
PS C:\> Invoke-UdeDbQuery -Id "motz01-reader" -Query "SELECT TOP (10) name FROM sys.tables ORDER BY name"
```

This will cache Reader JIT access credentials for the environment "es-ude-motz-01" (waiting 60 seconds
for backend propagation) and then execute the query using the cached credentials.
It will return one object per row.

### EXAMPLE 2
```
Invoke-UdeDbQuery -Id "motz01-writer" -Query "UPDATE dbo.MyTable SET MyColumn = 1 WHERE Id = 42"
```

This will execute the data modifying statement using the cached Writer JIT access credentials
for the ID "motz01-writer" and return the number of affected rows.

### EXAMPLE 3
```
Get-UdeDbJitCache -Id "motz01-reader" | Invoke-UdeDbQuery -Query "SELECT * FROM dbo.MyTable" -AsExcelOutput
```

This will execute the query using the cached JIT access credentials piped in from Get-UdeDbJitCache.
It will output all details directly to an Excel file.

## PARAMETERS

### -Id
The unique identifier of the cached JIT access credentials to use.

Supports wildcard patterns.
If multiple cached credentials match, the cmdlet stops and asks
you to be specific.

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

### -Query
The SQL query to execute against the environment database.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -QueryTimeout
The time in seconds to wait for the query to execute before timing out.

Defaults to 60.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instruct the cmdlet to output all details directly to an Excel file.

Will include all properties, including those not shown by default in the console output.

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
