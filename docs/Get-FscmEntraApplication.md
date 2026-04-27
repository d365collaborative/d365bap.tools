---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmEntraApplication

## SYNOPSIS
Get Entra (AAD) registered applications from a Finance and Operations environment.

## SYNTAX

```
Get-FscmEntraApplication [-EnvironmentId] <String> [[-ClientId] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Retrieves the registered Entra (Azure AD) client applications from the SysAADClients OData entity in a Finance and Operations environment.

Supports wildcard and exact matching against the ClientId (AadClientId), Name, and UserId fields.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv"
```

This command retrieves all Entra registered applications from the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001"
```

This command retrieves the Entra application with the exact client ID "00000000-0000-0000-0000-000000000001" from the environment "ContosoEnv".

The filter is matched against the ClientId (AadClientId), Name, and UserId fields.

### EXAMPLE 3
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "*1234*"
```

This command retrieves all Entra applications where the ClientId (AadClientId), Name, or UserId contains "1234" from the environment "ContosoEnv".

### EXAMPLE 4
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "IntegrationApp"
```

This command retrieves the Entra application with the exact Name "IntegrationApp" from the environment "ContosoEnv".

The filter is matched against the ClientId (AadClientId), Name, and UserId fields.

### EXAMPLE 5
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "*Integration*"
```

This command retrieves all Entra applications where the ClientId (AadClientId), Name, or UserId contains "Integration" from the environment "ContosoEnv".

### EXAMPLE 6
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "Admin"
```

This command retrieves the Entra application associated with the UserId "Admin" from the environment "ContosoEnv".

The filter is matched against the ClientId (AadClientId), Name, and UserId fields.

### EXAMPLE 7
```
Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -AsExcelOutput
```

This command retrieves all Entra registered applications from the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to retrieve Entra applications from.

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

### -ClientId
The value to filter the results by.

Filters across the ClientId (AadClientId), Name, and UserId fields - any match on any of the three will include the record.

Supports wildcard characters for flexible matching.

Default value is "*", which returns all registered applications.

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
Instructs the cmdlet to export the retrieved application information to an Excel file.

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
