---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Compare-BapEnvironmentVirtualEntity

## SYNOPSIS
Compare environment Virtual Entities

## SYNTAX

```
Compare-BapEnvironmentVirtualEntity [-SourceEnvironmentId] <String> [-DestinationEnvironmentId] <String>
 [-ShowDiffOnly] [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to compare 2 x environments, with one as a source and the other as a destination

It will only look for enabled / visible Virtual Entities on the source, and use this as a baseline against the destination

## EXAMPLES

### EXAMPLE 1
```
Compare-BapEnvironmentVirtualEntity -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
```

This will get all enabled / visible Virtual Entities from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.

Sample output:
EntityName                     SourceIsVisible SourceChangeTrackingEnabled Destination DestinationChange
IsVisible   TrackingEnabled
----------                     --------------- --------------------------- ----------- -----------------
AccountantEntity               True            False                       True        False
CurrencyEntity                 True            False                       False       False
WMHEOutboundQueueEntity        True            False                       False       False

### EXAMPLE 2
```
Compare-BapEnvironmentVirtualEntity -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -ShowDiffOnly
```

This will get all enabled / visible Virtual Entities from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will filter out results, to only include those where the Source is different from the Destination.

Sample output:
EntityName                     SourceIsVisible SourceChangeTrackingEnabled Destination DestinationChange
IsVisible   TrackingEnabled
----------                     --------------- --------------------------- ----------- -----------------
CurrencyEntity                 True            False                       False       False
WMHEOutboundQueueEntity        True            False                       False       False

### EXAMPLE 3
```
Compare-BapEnvironmentVirtualEntity -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
```

This will get all enabled / visible Virtual Entities from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -SourceEnvironmentId
Environment Id of the source environment that you want to utilized as the baseline for the compare

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

### -DestinationEnvironmentId
Environment Id of the destination environment that you want to validate against the baseline (source)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowDiffOnly
Instruct the cmdlet to only output the differences that are not aligned between the source and destination

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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
