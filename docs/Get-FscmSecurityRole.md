---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmSecurityRole

## SYNOPSIS
Get information about Finance and Operations security roles in a given environment.

## SYNTAX

```
Get-FscmSecurityRole [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet retrieves information about Finance and Operations security roles in a given environment.
It allows filtering by role name or ID, and exporting the results to Excel.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -Name "System Administrator"
```

This command retrieves the Finance and Operations security role with the name "System Administrator" from the environment "ContosoEnv" and displays its information in the console.

### EXAMPLE 2
```
Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -Name "*sys*admin*"
```

This command retrieves all Finance and Operations security roles with names matching "*sys*admin*" from the environment "ContosoEnv" and displays their information in the console.

### EXAMPLE 3
```
Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves all Finance and Operations security roles from the environment "ContosoEnv".
It will export the information to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve security roles from.

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
The name or ID of the security role to retrieve.

Can be either the role name or the role ID.

Supports wildcard characters for flexible matching.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Role

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to export the retrieved security role information to an Excel file.

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
