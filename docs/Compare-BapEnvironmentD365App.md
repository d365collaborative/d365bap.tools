---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Compare-BapEnvironmentD365App

## SYNOPSIS
Compare environment D365 Apps

## SYNTAX

```
Compare-BapEnvironmentD365App [-SourceEnvironmentId] <String> [-DestinationEnvironmentId] <String>
 [-ShowDiffOnly] [[-GeoRegion] <String>] [-AsExcelOutput] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to compare 2 x environments, with one as a source and the other as a destination

It will only look for installed D365 Apps on the source, and use this as a baseline against the destination

## EXAMPLES

### EXAMPLE 1
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test*
```

This will get all installed D365 Apps from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.

Sample output:
PpacD365AppName                      PpacPackageName                SourceVersion       DestinationVersion
---------------                      ---------------                -------------       ------------------
Agent Productivity Tools             AgentProductivityToolsAnchor   9.2.24083.1006      9.2.24083.1006
appprofilemanager                    msdyn_AppProfileManagerAnchor  10.1.24083.1006     10.1.24083.1006
Business Copilot AI                  msdyn_BusinessCopilotAIAnchor  1.0.0.23            1.0.0.23
Copilot for finance and operations … msdyn_FnOCopilotAnchor         1.0.2748.3          1.0.2748.3
Copilot in Microsoft Dynamics 365 F… msdyn_FinanceAIAppAnchor       1.0.2755.2          1.0.2755.2
Copilot in Microsoft Dynamics 365 S… msdyn_SCMAIAppAnchor           1.0.2731.2          1.0.2731.2

### EXAMPLE 2
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -ShowDiffOnly
```

This will get all installed D365 Apps from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will filter out results, to only include those where the DestinationVersions is different from the SourceVersion.

Sample output:
PpacD365AppName                      PpacPackageName                SourceVersion       DestinationVersion
---------------                      ---------------                -------------       ------------------
Dataverse Accelerator                DataverseAccelerator_Anchor    1.0.5.6             1.0.4.36
Dynamics 365 ChannelExperienceApps   msdyn_ChannelExperienceAppsAn… 1.0.24074.1004      1.0.24083.1004
Invoice Capture for Dynamics 365 Fi… msdyn_FnoInvoiceCaptureAnchor  1.7.0.1             Missing
OData v4 Data Provider               ODatav4DataProvider            9.1.0.203           9.1.0.226

### EXAMPLE 3
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -AsExcelOutput
```

This will get all installed D365 Apps from the Source Environment.
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

### -GeoRegion
Instructs the cmdlet which Geo / Region the environment is located

The default value is: "Emea"

This is mandatory field from the API specification, we don't have the full list of values at the time of writing

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Emea
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
