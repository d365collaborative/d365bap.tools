---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmInstalledModel

## SYNOPSIS
Get installed models from a Finance and Operations environment.

## SYNTAX

```
Get-FscmInstalledModel [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the list of installed models from a Finance and Operations environment using the GetInstalledModules OData action.

Each installed model is parsed into its Name, Version, Module, Publisher, and DisplayName parts.

Supports wildcard and exact matching against the Name, DisplayName, and Module fields.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmInstalledModel -EnvironmentId "ContosoEnv"
```

This command retrieves all installed models from the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -Name "*Application*"
```

This command retrieves all installed models whose Name, DisplayName, or Module contains "Application" from the environment "ContosoEnv".

### EXAMPLE 3
```
Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -Name "ApplicationSuite"
```

This command retrieves installed models with the Module "ApplicationSuite" from the environment "ContosoEnv".

The filter matches against the model Name, DisplayName, and Module fields.

### EXAMPLE 4
```
Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves all installed models from the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve installed models from.

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
The value to filter the results by.

Filters against the model Name, DisplayName, and Module fields - any match on any of the three will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all installed models.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to export the retrieved installed models to an Excel file.

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
