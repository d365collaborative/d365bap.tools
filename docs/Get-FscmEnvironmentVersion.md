---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmEnvironmentVersion

## SYNOPSIS
Get version numbers from a Finance and Operations environment.

## SYNTAX

```
Get-FscmEnvironmentVersion [-EnvironmentId] <String> [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Retrieves the application version, application build version, and platform build version from a Finance and Operations environment using OData actions.

Returns a single object with the ApplicationVersion, ApplicationBuild, and PlatformBuild values.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmEnvironmentVersion -EnvironmentId "ContosoEnv"
```

This command retrieves the version numbers from the environment "ContosoEnv" and displays them in the console.

### EXAMPLE 2
```
Get-FscmEnvironmentVersion -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves the version numbers from the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve version numbers from.

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

### -AsExcelOutput
Instructs the cmdlet to export the retrieved version numbers to an Excel file.

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

### System.Object
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
