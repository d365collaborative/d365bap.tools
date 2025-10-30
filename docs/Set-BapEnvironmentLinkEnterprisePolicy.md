---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Set-BapEnvironmentLinkEnterprisePolicy

## SYNOPSIS
Set the link between Dataverse and the Enterprise Policy

## SYNTAX

```
Set-BapEnvironmentLinkEnterprisePolicy [-EnvironmentId] <String> [-EnterprisePolicyResourceId] <String>
 [<CommonParameters>]
```

## DESCRIPTION
To enable managed identity between Dataverse and Azure resources, you will need to work with the Enterprise Policy concept

It needs to be linked, based on the SystemId of the Enterprise Policy (Azure) and the Dataverse environment (Id)

## EXAMPLES

### EXAMPLE 1
```
Set-BapEnvironmentLinkEnterprisePolicy -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -EnterprisePolicyResourceId '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-01/providers/Microsoft.PowerPlatform/enterprisePolicies/EnterprisePolicy-Dataverse'
```

This will link the Dataverse Environment to the Enterprise Policy.
The Environment is 'eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6'.
The EnterprisePolicy is '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-01/providers/Microsoft.PowerPlatform/enterprisePolicies/EnterprisePolicy-Dataverse'

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

### -EnterprisePolicyResourceId
The (system) id of the Enterprise Policy that you want to link to your Dataverse environment

```yaml
Type: String
Parameter Sets: (All)
Aliases: SystemId

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
