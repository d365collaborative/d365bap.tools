---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpeCustomApi

## SYNOPSIS
Get custom APIs from a Power Platform / Dataverse environment.

## SYNTAX

```
Get-PpeCustomApi [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves custom API definitions from the Dataverse /api/data/v9.2/customapis endpoint, returning discovery information for each API.

Results show the unique name, whether the API is a Function (HTTP GET) or an Action (HTTP POST), the binding type (Global, Entity, EntityCollection) and whether the API is private.

A private API (IsPrivate) is hidden from the Web API $metadata document and code generation tools, but it can still be invoked through the Web API and the SOAP Organization Service (Execute) when the unique name is known.
No custom API is SOAP-only.

## EXAMPLES

### EXAMPLE 1
```
Get-PpeCustomApi -EnvironmentId "ContosoEnv"
```

This command retrieves all custom APIs in the environment "ContosoEnv".

### EXAMPLE 2
```
Get-PpeCustomApi -EnvironmentId "ContosoEnv" -Name "msprov_*"
```

This command retrieves all custom APIs whose unique name starts with "msprov_" from the environment "ContosoEnv".

### EXAMPLE 3
```
Get-PpeCustomApi -EnvironmentId "ContosoEnv" -Name "*fino*"
```

This command retrieves all custom APIs whose unique name, name or display name contains "fino" from the environment "ContosoEnv".

### EXAMPLE 4
```
Get-PpeCustomApi -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves all custom APIs in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve custom APIs from.

Can be either the environment name or the environment GUID (PPAC).

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

Filters against the custom API UniqueName, Name and DisplayName fields - any match on either will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all custom APIs.

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
Instructs the cmdlet to export the retrieved custom APIs to an Excel file.

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
