---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironment

## SYNOPSIS
Get information about Power Platform environments as listed in the Power Platform Admin Center (PPAC).

## SYNTAX

```
Get-BapEnvironment [[-EnvironmentId] <String>] [-FnoEnabled] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet retrieves information about Power Platform environments from the Power Platform Admin Center (PPAC).
It allows filtering by environment ID, checking for Finance and Operations enabled environments, and exporting the results to Excel.

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironment
```

This command retrieves all Power Platform environments listed in the Power Platform Admin Center (PPAC) and displays their information in the console.

### EXAMPLE 2
```
Get-BapEnvironment -EnvironmentId "Contoso*"
```

This command retrieves all Power Platform environments matching "Contoso*" and displays their information in the console.
It will match environments with names, display names, or linked app metadata IDs against "Contoso*".

### EXAMPLE 3
```
Get-BapEnvironment -FnoEnabled
```

This command retrieves all Power Platform environments that are enabled for Finance and Operations and displays their information in the console.

### EXAMPLE 4
```
Get-BapEnvironment -AsExcelOutput
```

This command retrieves all Power Platform environments and exports their information to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

Supports wildcard characters for flexible matching.

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
Instructs the cmdlet to filter and return only environments that are enabled for Finance and Operations.

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
Instructs the cmdlet to export the retrieved environment information to an Excel file.

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
