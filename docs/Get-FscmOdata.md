---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-FscmOdata

## SYNOPSIS
Query an OData entity from a Finance and Operations environment.

## SYNTAX

### NextLink
```
Get-FscmOdata -EnvironmentId <String> [-Entity <String>] [-ODataQuery <String>] [-CrossCompany]
 [-TraverseNextLink] [-ThrottleSeed <Int32>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### Default
```
Get-FscmOdata -EnvironmentId <String> -Entity <String> [-ODataQuery <String>] [-CrossCompany] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Invokes a GET request against the Finance and Operations OData endpoint for the specified entity, handling authentication, optional query filters, cross-company access, and automatic pagination via nextLink traversal.

Includes built-in retry logic for 429 (Too Many Requests) responses.

## EXAMPLES

### EXAMPLE 1
```
Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients"
```

This command retrieves all records from the SysAADClients OData entity in the environment "ContosoEnv".

### EXAMPLE 2
```
Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SystemUsers" -ODataQuery "`$filter=IsActive eq true"
```

This command retrieves all active system users from the environment "ContosoEnv" using an OData filter.

### EXAMPLE 3
```
Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SystemUsers" -CrossCompany
```

This command retrieves system users across all legal entities in the environment "ContosoEnv".

### EXAMPLE 4
```
Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -TraverseNextLink
```

This command retrieves all records from the SysAADClients entity, following pagination links until all pages are returned.

### EXAMPLE 5
```
Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -TraverseNextLink -ThrottleSeed 3
```

This command retrieves all pages from the SysAADClients entity, pausing between 1 and 3 seconds between each page request to reduce the risk of throttling.

### EXAMPLE 6
```
Get-FscmOdata -EnvironmentId "ContosoEnv" -Entity "SysAADClients" -AsExcelOutput
```

This command retrieves all records from the SysAADClients entity in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to query.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Entity
The OData entity name to query, e.g.
"SysAADClients" or "SystemUsers".

```yaml
Type: String
Parameter Sets: NextLink
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: Default
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ODataQuery
An optional OData query string to append to the request, e.g.
"\`$filter=IsActive eq true&\`$select=UserId,Name".

Do not include the leading "?".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CrossCompany
Instructs the cmdlet to append "cross-company=true" to the request, returning records across all legal entities.

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

### -TraverseNextLink
Instructs the cmdlet to follow "@odata.nextLink" pagination and accumulate all pages into the result.

Must be used together with the NextLink parameter set.

```yaml
Type: SwitchParameter
Parameter Sets: NextLink
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ThrottleSeed
When specified, introduces a random delay between 1 and ThrottleSeed seconds after each page request to reduce throttling risk.

Only valid when TraverseNextLink is also specified.

```yaml
Type: Int32
Parameter Sets: NextLink
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instructs the cmdlet to export the retrieved records to an Excel file.

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
