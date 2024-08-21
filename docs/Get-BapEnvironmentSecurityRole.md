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
Get-BapEnvironmentSecurityRole [-EnvironmentId] <String> [[-Name] <String>] [-IncludeAll] [-AsExcelOutput]
 [<CommonParameters>]
```

## DESCRIPTION
Get Security Roles from the Dataverse environment

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will list all Security Roles from the Dataverse environment, by the EnvironmentId (guid).
It will only list the Security Roles that are tied to the Environment.

Sample output:
Id                                   Name                                     IsManaged RoleType
--                                   ----                                     --------- --------
5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Featureâ€¦ True      Environment
1cbf96a1-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Featureâ€¦ True      Environment
d364ba1c-1bfb-eb11-94f0-0022482381ee Accounts Payable Admin                   True      Environment

### EXAMPLE 2
```
Get-BapEnvironmentSecurityRole -EnvironmentId *uat*
```

This will list all Security Roles from the Dataverse environment, by the EnvironmentId (Name/Wildcard).
It will only list the Security Roles that are tied to the Environment.

Sample output:
Id                                   Name                                     IsManaged RoleType
--                                   ----                                     --------- --------
5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Featureâ€¦ True      Environment
1cbf96a1-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Featureâ€¦ True      Environment
d364ba1c-1bfb-eb11-94f0-0022482381ee Accounts Payable Admin                   True      Environment

### EXAMPLE 3
```
Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "*Administrator*"
```

This will list all Security Roles, which matches the "*Administrator*" pattern, from the Dataverse environment.
It will only list the Security Roles that are tied to the Environment.

Sample output:
Id                                   Name                                     IsManaged RoleType
--                                   ----                                     --------- --------
5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Featureâ€¦ True      Environment
4758a2be-ccd8-ea11-a813-000d3a579805 App Profile Manager Administrator        True      Environment
470a750f-d810-4ee7-a64a-ec002965c1ec Copilot for Service Administrator        True      Environment
5e4a9faa-b260-e611-8106-00155db8820b IoT - Administrator                      True      Environment
947229e9-e868-45cf-a361-5635eaf35ee2 Microsoft Copilot Administrator          True      Environment
f7f90019-dc14-e911-816a-000d3a069ebd Omnichannel administrator                True      Environment
6beb51c1-0eda-e911-a81c-000d3af75d63 Productivity tools administrator         True      Environment
ebbb3fcb-fcd7-4bf8-9a48-7b5a9878e79e Sales Copilot Administrator              True      Environment
abce3b01-5697-4973-9d7d-fca48ca84445 Survey Services Administrator(Deprecateâ€¦ True      Environment
63e389ae-bc55-ec11-8f8f-6045bd88b210 System Administrator                     True      Environment

### EXAMPLE 4
```
Get-BapEnvironmentSecurityRole -EnvironmentId *uat* -Name "System Administrator"
```

This will list all Security Roles, which matches the "System Administrator" pattern, from the Dataverse environment.
It will only list the Security Roles that are tied to the Environment.

Sample output:
Id                                   Name                                     IsManaged RoleType
--                                   ----                                     --------- --------
63e389ae-bc55-ec11-8f8f-6045bd88b210 System Administrator                     True      Environment

### EXAMPLE 5
```
Get-BapEnvironmentSecurityRole -EnvironmentId *uat* -Name "System Administrator" -IncludeAll
```

This will list all Security Roles, which matches the "System Administrator" pattern, from the Dataverse environment.
It will only list the Security Roles that are tied to the Environment.

Sample output:
Id                                   Name                                     IsManaged RoleType
--                                   ----                                     --------- --------
0cdbad8e-72e7-406c-ae38-8c4406caea59 System Administrator                     False     BusinessUnit
63e389ae-bc55-ec11-8f8f-6045bd88b210 System Administrator                     True      Environment

### EXAMPLE 6
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

### -IncludeAll
Instruct the cmdlet to output all security roles, regardless of their type

This will output all security roles, including the ones that are tied to Business Units, which at first glance might seem like duplicates

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
