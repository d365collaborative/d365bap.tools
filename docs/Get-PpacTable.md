---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacTable

## SYNOPSIS
Get the tables (entities) from a given environment.

## SYNTAX

```
Get-PpacTable [-EnvironmentId] <String> [[-Name] <String>] [-OnlyCustom] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet retrieves all tables (entities) from a given Power Platform environment.

It mimics the "Tables" view in the Power Apps maker portal, showing the table display name, logical name, type, managed state and customizability.

It is not specific to any security role - use the Get-PpacSecurityRoleTable cmdlet to see the tables assigned to a security role.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacTable -EnvironmentId "ContosoEnv"
```

This command retrieves all tables from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 2
```
Get-PpacTable -EnvironmentId "ContosoEnv" -Name "*account*"
```

This command retrieves all tables with display names or logical names matching "*account*" from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 3
```
Get-PpacTable -EnvironmentId "ContosoEnv" -OnlyCustom
```

This command retrieves only the custom tables from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 4
```
Get-PpacTable -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves all tables from the environment "ContosoEnv".
It will export the information to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve the tables from.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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

### -Name
The name of the table to filter the tables by.

Can be either the table display name or the logical name.

Supports wildcard characters for flexible matching.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Table

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -OnlyCustom
Instructs the cmdlet to only include custom tables in the results.

This matches the "Custom" filter in the Power Apps maker portal.

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
Instructs the cmdlet to export the retrieved table information to an Excel file.

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
Author: Trygve Bechsgaard

## RELATED LINKS
