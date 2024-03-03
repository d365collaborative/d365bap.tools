---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentVirtualEntity

## SYNOPSIS
Get Virtual Entity from environment

## SYNTAX

```
Get-BapEnvironmentVirtualEntity [-EnvironmentId] <String> [[-Name] <String>] [-VisibleOnly] [-AsExcelOutput]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to query against the Virtual Entities from the D365FO environment

This will help determine which Virtual Entities are already enabled / visible and their state, as they are seeing from the Dataverse environment

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will fetch all virtual entities from the environment.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
AadWorkerIntegrationEntity     False     False                 00002893-0000-0000-560a-005001000000
AbbreviationsEntity            False     False                 00002893-0000-0000-5002-005001000000
AccountantEntity               False     False                 00002893-0000-0000-0003-005001000000
AccountingDistributionBiEntity False     False                 00002893-0000-0000-d914-005001000000
AccountingEventBiEntity        False     False                 00002893-0000-0000-d414-005001000000

### EXAMPLE 2
```
Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -VisibleOnly
```

This will fetch visble only virtual entities from the environment.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
CurrencyEntity                 True      False                 00002893-0000-0000-c30b-005001000000
WMHEOutboundQueueEntity        True      False                 00002893-0000-0000-f30b-005001000000

### EXAMPLE 3
```
Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
```

This will fetch all virtual entities from the environment.
Will output all details into an Excel file, that will auto open on your machine.

### EXAMPLE 4
```
Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "Retail*"
```

This will fetch all virtual entities that contains the "Retail" text in the name, from the environment.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
CustHierarchyRetailChannelEnt… False     False                 00002893-0000-0000-e314-005001000000
DimAttributeRetailChannelEnti… False     False                 00002893-0000-0000-0804-005001000000
DimAttributeRetailStoreEntity  False     False                 00002893-0000-0000-0f03-005001000000
DimAttributeRetailTerminalEnt… False     False                 00002893-0000-0000-6e07-005001000000
EcoResRetailProductEntity      False     False                 00002893-0000-0000-ae06-005001000000

### EXAMPLE 5
```
Get-BapEnvironmentVirtualEntity -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name AccountantEntity
```

This will fetch the specific virtual entity from the environment.

Sample output:
EntityName                     IsVisible ChangeTrackingEnabled EntityGuid
----------                     --------- --------------------- ----------
AccountantEntity               False     False                 00002893-0000-0000-0003-005001000000

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
The name of the virtual entity that you are looking for

The parameter supports wildcards, but will resolve them into a strategy that matches best practice from Microsoft documentation

It means that you can only have a single search phrase.
E.g.
* -Name "*Retail"
* -Name "Retail*"
* -Name "*Retail*"

Multiple search phrases are not going to produce an output, as it will be striped into an invalid search string.
E.g.
!
-Name "*Retail*Entity*" -\> "RetailEntity"
!
-Name "Retail*Entity" -\> "RetailEntity"
!
-Name "*Retail*Entity" -\> "RetailEntity"
!
-Name "Retail*Entity*" -\> "RetailEntity"

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

### -VisibleOnly
Instruct the cmdlet to only output those virtual entities that are enabled / visible

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
