---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentLinkEnterprisePolicy

## SYNOPSIS
Get Enterprise Policy

## SYNTAX

```
Get-BapEnvironmentLinkEnterprisePolicy [-EnvironmentId] <String> [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Get all registered Enterprise Policies from a Dataverse environment and its linked status

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentLinkEnterprisePolicy -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will get all Enterprise Policy informations from the Dataverse environment.

Sample output:
PpacEnvId   : eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
PpacEnvName : new-test
Type        : identity
policyId    : d3e06308-e287-42bb-ad6d-a588ef77d6e8
location    : europe
id          : /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-01/providers/Microsoft.PowerPlatfor
m/enterprisePolicies/EnterprisePolicy-Dataverse
systemId    : /regions/europe/providers/Microsoft.PowerPlatform/enterprisePolicies/d3e06308-e287-42bb-ad6d-a588ef77d6e8
linkStatus  : Linked

### EXAMPLE 2
```
Get-BapEnvironmentLinkEnterprisePolicy -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
```

This will get all Enterprise Policy informations from the Dataverse environment.
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
