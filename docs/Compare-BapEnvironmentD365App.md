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
 [-ShowDiffOnly] [[-GeoRegion] <String>] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to compare 2 x environments, with one as a source and the other as a destination

It will only look for installed D365 Apps on the source, and use this as a baseline against the destination

## EXAMPLES

### EXAMPLE 1
```
Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1
```

This will get all installed D365 Apps from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.

Sample output:
PackageId                            PackageName                    SourceVersion       DestinationVersion  AppName
---------                            -----------                    -------------       ------------------  -------
ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24012.1005      Agent Prodâ€¦
1c0a1237-9408-4b99-9fec-39696d99287b msdyn_AppProfileManagerAnchor  10.1.24021.1005     10.1.24012.1013     appprofileâ€¦
6ce2d70e-78bf-4ff6-85ed-1bd63d4ab444 ExportToDataLakeCoreAnchor     1.0.0.1             0.0.0.0             Azure Synaâ€¦
42cc1442-194f-462b-a325-ce5b5f18c02d msdyn_EmailAddressValidation   1.0.0.4             1.0.0.4             Data Validâ€¦

### EXAMPLE 2
```
Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -ShowDiffOnly
```

This will get all installed D365 Apps from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will filter out results, to only include those where the DestinationVersions is different from the SourceVersion.

Sample output:
PackageId                            PackageName                    SourceVersion       DestinationVersion  AppName
---------                            -----------                    -------------       ------------------  -------
ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24012.1005      Agent Prodâ€¦
1c0a1237-9408-4b99-9fec-39696d99287b msdyn_AppProfileManagerAnchor  10.1.24021.1005     10.1.24012.1013     appprofileâ€¦
6ce2d70e-78bf-4ff6-85ed-1bd63d4ab444 ExportToDataLakeCoreAnchor     1.0.0.1             0.0.0.0             Azure Synaâ€¦
7523d261-f1be-46e7-8e68-f3de16eeabbb DualWriteCoreAnchor            1.0.24022.4         1.0.24011.1         Dual-writeâ€¦

### EXAMPLE 3
```
Compare-BapEnvironmentD365App -SourceEnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -DestinationEnvironmentId 32c6b196-ef52-4c43-93cf-6ecba51e6aa1 -AsExcelOutput
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
