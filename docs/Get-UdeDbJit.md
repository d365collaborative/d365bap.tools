---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-UdeDbJit

## SYNOPSIS
Gets UDE database JIT access information for a specified environment.

## SYNTAX

```
Get-UdeDbJit [-EnvironmentId] <String> [[-WhitelistIp] <String>] [[-Role] <String>] [[-Reason] <String>]
 [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves UDE database JIT access information for a specified environment.

## EXAMPLES

### EXAMPLE 1
```
Get-UdeDbJit -EnvironmentId "env-123"
```

This will retrieve the JIT database access information for the specified environment ID.
It will whitelist the public IP address of the machine running the command.
It will assign the "Reader" role.
It will use the default reason.

### EXAMPLE 2
```
Get-UdeDbJit -EnvironmentId "env-123" -WhitelistIp "85.168.174.10"
```

This will retrieve the JIT database access information for the specified environment ID.
It will whitelist the specified IP address "85.168.174.10".
It will assign the "Reader" role.
It will use the default reason.

### EXAMPLE 3
```
Get-UdeDbJit -EnvironmentId "env-123" -Role "Writer"
```

This will retrieve the JIT database access information for the specified environment ID.
It will whitelist the public IP address of the machine running the command.
It will assign the "Writer" role.
It will use the default reason.

### EXAMPLE 4
```
Get-UdeDbJit -EnvironmentId "env-123" -Reason "Needed for data migration"
```

This will retrieve the JIT database access information for the specified environment ID.
It will whitelist the public IP address of the machine running the command.
It will assign the "Reader" role.
It will use the specified reason "Needed for data migration".

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhitelistIp
Ip address to whitelist for JIT database access.

Defaults to 127.0.0.1 - which will cause the function to determine the public IP address of the machine running the command.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 127.0.0.1
Accept pipeline input: False
Accept wildcard characters: False
```

### -Role
The role to assign for JIT database access.

Can be either "Reader" or "Writer".

Defaults to "Reader".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Reader
Accept pipeline input: False
Accept wildcard characters: False
```

### -Reason
The reason for requesting JIT database access.

Defaults to "Administrative access via d365bap.tools".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: Administrative access via d365bap.tools
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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
