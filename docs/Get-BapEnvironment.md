---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironment

## SYNOPSIS
Retrieves information about Power Platform environments.

## SYNTAX

```
Get-BapEnvironment [[-EnvironmentId] <String>] [-FscmEnabled] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves information about Power Platform environments from the Power Platform Admin Center (PPAC).

It allows filtering by environment ID, checking for Finance and Operations enabled environments, and exporting the results to Excel.

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironment
```

This will return all environments in the Power Platform tenant.

### EXAMPLE 2
```
Get-BapEnvironment -EnvironmentId "env-123"
```

This will return the environment with the id "env-123".

### EXAMPLE 3
```
Get-BapEnvironment -FscmEnabled
```

This will return all environments in the Power Platform tenant that have Dynamics 365 ERP suite capabilities.

### EXAMPLE 4
```
Get-BapEnvironment -FscmEnabled -AsExcelOutput
```

This will return all environments in the Power Platform tenant that have Dynamics 365 ERP suite capabilities.
It will export the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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

### -FscmEnabled
Instructs the function to only return environments that have Dynamics 365 ERP suite capabilities (environments that is either linked or provisioned as an unified environment).

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
Instructs the function to export the results to an Excel file.

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
