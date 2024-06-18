---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentSecurityRole

## SYNOPSIS
Get Security Roles from environment

## SYNTAX

```
Get-BapEnvironmentSecurityRole [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [<CommonParameters>]
```

## DESCRIPTION
Get Security Roles from the Dataverse environment

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will list all Security Roles from the Dataverse environment.

Sample output:
Id                                   Name                           ModifiedOn
--                                   ----                           ----------
5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realti… 03/02/2023 10.11.13
1cbf96a1-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realti… 03/02/2023 10.11.14
d364ba1c-1bfb-eb11-94f0-0022482381ee Accounts Payable Admin         17/08/2023 07.06.15

### EXAMPLE 2
```
Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "Environment*"
```

This will list all Security Roles, which matches the "Environment*" pattern, from the Dataverse environment.

Sample output:
Id                                   Name                           ModifiedOn
--                                   ----                           ----------
d58407f2-48d5-e711-a82c-000d3a37c848 Environment Maker              15/06/2024 21.12.56

### EXAMPLE 3
```
Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
```

This will list all Security Roles from the Dataverse environment.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

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
Name of the Security Role that you want to work against

Supports wildcard search

Default value is "*" - which translates into all available Security Roles

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
Instruct the cmdlet to output all details directly to an Excel file

This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
General notes

## RELATED LINKS
