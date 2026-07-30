---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpacSecurityRoleTable

## SYNOPSIS
Get the tables assigned to a security role in a given environment.

## SYNTAX

```
Get-PpacSecurityRoleTable [-EnvironmentId] <String> [-Role] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet retrieves the tables (entities) that have privileges assigned to a security role in a given Power Platform environment.

For each table it outputs the access level for each of the privilege types: Create, Read, Write, Delete, Append, AppendTo, Assign and Share.

The access levels are displayed with the Power Platform admin center naming: None, User, Business Unit, Parent: Child Business Unit, Organization.

It mimics the "Tables" view of the security role editor in the Power Platform admin center, with the "Show only assigned tables" filter applied.

Use the Get-PpacTable cmdlet to see all tables available in the environment.

## EXAMPLES

### EXAMPLE 1
```
Get-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader"
```

This command retrieves the tables that have privileges assigned to the security role "Monitoring Reader" in the environment "ContosoEnv".
It will show the access level for each privilege type on each table.

### EXAMPLE 2
```
Get-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Name "*business*"
```

This command retrieves the tables with display names or logical names matching "*business*", that have privileges assigned to the security role "Monitoring Reader" in the environment "ContosoEnv".

### EXAMPLE 3
```
Get-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -AsExcelOutput
```

This command retrieves the tables that have privileges assigned to the security role "Monitoring Reader" in the environment "ContosoEnv".
It will export the information to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve the security role tables from.

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

### -Role
The security role that you want to work against.

Can be either the role name or the role ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 2
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
Aliases:

Required: False
Position: 3
Default value: *
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
