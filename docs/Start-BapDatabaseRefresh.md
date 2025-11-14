---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Start-BapDatabaseRefresh

## SYNOPSIS
Start a database refresh between two environments

## SYNTAX

```
Start-BapDatabaseRefresh [-SourceEnvironmentId] <String> [[-TargetEnvironmentId] <String>]
 [[-CopyType] <String>] [-IncludeAuditData] [-AdvancedFnO] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to start a database refresh between two environments in the same tenant.

The source and target environments must both be either managed or unmanaged.

## EXAMPLES

### EXAMPLE 1
```
Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat*
```

This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
It defaults to a full copy.

### EXAMPLE 2
```
Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType FullCopy
```

This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".

### EXAMPLE 3
```
Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType TransactionLess
```

This will start a transaction-less database refresh from the environment with id containing "dev" to the environment with id containing "uat".

### EXAMPLE 4
```
Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType FullCopy -IncludeAuditData
```

This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
It will include audit data in the copy.

### EXAMPLE 5
```
Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType FullCopy -AdvancedFnO
```

This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
It will execute an advanced copy for Finance and Operations.

## PARAMETERS

### -SourceEnvironmentId
Id of the source environment that you want to copy the database from.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Source

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TargetEnvironmentId
Id of the target environment that you want to copy the database to.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Target

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CopyType
Type of copy to perform.

Valid values are "FullCopy" and "TransactionLess".

Default is "FullCopy".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: FullCopy
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeAuditData
Instructs the cmdlet to include audit data in the copy.

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

### -AdvancedFnO
Instructs the cmdlet to execute an advanced copy for Finance and Operations.

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
