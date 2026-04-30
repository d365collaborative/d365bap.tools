---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-PpeOdata

## SYNOPSIS
Query an OData entity from a Power Platform / Dataverse environment.

## SYNTAX

### Default (Default)
```
Get-PpeOdata -EnvironmentId <String> -Entity <String> [-ODataQuery <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### NextLink
```
Get-PpeOdata -EnvironmentId <String> -Entity <String> [-ODataQuery <String>] [-TraverseNextLink]
 [-ThrottleSeed <Int32>] [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Invokes a GET request against the Dataverse Web API OData endpoint for the specified entity, handling authentication, optional query filters, and automatic pagination via nextLink traversal.

Includes built-in retry logic for 429 (Too Many Requests) responses.

## EXAMPLES

### EXAMPLE 1
```
Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts"
```

This command retrieves all records from the accounts entity in the environment "ContosoEnv".

### EXAMPLE 2
```
Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "systemusers" -ODataQuery "`$filter=isdisabled eq false&`$select=fullname,systemuserid"
```

This command retrieves all enabled system users, returning only the fullname and systemuserid fields.

### EXAMPLE 3
```
Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -TraverseNextLink
```

This command retrieves all records from the accounts entity, following pagination links until all pages are returned.

### EXAMPLE 4
```
Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -TraverseNextLink -ThrottleSeed 3
```

This command retrieves all pages from the accounts entity, pausing between 1 and 3 seconds between each page request to reduce the risk of throttling.

### EXAMPLE 5
```
Get-PpeOdata -EnvironmentId "ContosoEnv" -Entity "accounts" -AsExcelOutput
```

This command retrieves all records from the accounts entity in the environment "ContosoEnv" and exports the results to an Excel file.

## PARAMETERS

### -EnvironmentId
The ID of the environment to query.

Can be either the environment name or the environment GUID (PPAC).

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
The OData entity (plural name) to query, e.g.
"accounts" or "systemusers".

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

### -ODataQuery
An optional OData query string to append to the request, e.g.
"\`$filter=statecode eq 0&\`$select=name,accountid".

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
