---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentD365App

## SYNOPSIS
Get D365 App from the environment

## SYNTAX

```
Get-BapEnvironmentD365App [-EnvironmentId] <String> [[-Name] <String>] [[-Status] <String>]
 [[-GeoRegion] <String>] [-IncludeAll] [-UpdatesOnly] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to analyze and validate the current D365 Apps and their state, on a given environment

It can show all available D365 Apps - including their InstallState

It can show only installed D365 Apps

It can show only installed D365 Apps, with available updates

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will query the environment for ALL available D365 Apps.
It will output the ones that are either installed or in a failed install state.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:

PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
appprofilemanager              msdyn_AppProfileManagerAnchor  10.1.24072.1008     False           Installed
Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
Copilot for finance and ope...
msdyn_FnOCopilotAnchor         1.0.02748.3         False           Installed

### EXAMPLE 2
```
Get-BapEnvironmentD365App -EnvironmentId *test*
```

This will query the environment for ALL available D365 Apps.
It will output the ones that are either installed or in a failed install state.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:

PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
appprofilemanager              msdyn_AppProfileManagerAnchor  10.1.24072.1008     False           Installed
Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
Copilot for finance and ope...
msdyn_FnOCopilotAnchor         1.0.02748.3         False           Installed

### EXAMPLE 3
```
Get-BapEnvironmentD365App -EnvironmentId *test* -Status Installed
```

This will query the environment for installed only D365 Apps.
It will output the ones that are either installed or in a failed install state.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:
PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed
appprofilemanager              msdyn_AppProfileManagerAnchor  10.1.24072.1008     False           Installed
Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
Copilot for finance and ope...
msdyn_FnOCopilotAnchor         1.0.02748.3         False           Installed

### EXAMPLE 4
```
Get-BapEnvironmentD365App -EnvironmentId *test* -Status None
```

This will query the environment for NON-installed only D365 Apps.
It will output all details available for the D365 Apps.

Sample output:
PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
AI Builder for Project Cortex  SharePointFormProcessing       N/A                                 None
Analytics Custom Entities      AnalyticsCustomEntities        N/A                                 None
Analytics Custom Entities      AnalyticsCustomEntities_Anchor N/A                                 None
Awards and Recognitions Tem...
mpa_AwardsAndRecognition       N/A                                 None

### EXAMPLE 5
```
Get-BapEnvironmentD365App -EnvironmentId *test* -Status InstallFailed
```

This will query the environment for D365 Apps that are in a failed installation state.
It will output all details available for the D365 Apps.

Sample output:
PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
Azure Synapse Link for Datave… ExportToDataLakeCoreAnchor     N/A                                 InstallFailed

### EXAMPLE 6
```
Get-BapEnvironmentD365App -EnvironmentId *test* -Name "*ToolsAnchor*"
```

This will query the environment for ALL D365 Apps.
It will filter the output to only those who match the search pattern "*ToolsAnchor*".
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:
PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
Agent Productivity Tools       AgentProductivityToolsAnchor   9.2.24072.1003      False           Installed

### EXAMPLE 7
```
Get-BapEnvironmentD365App -EnvironmentId *test* -UpdatesOnly
```

This will query the environment for ALL available D365 Apps.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
It will filter the output to only containing those who have an update available.

Sample output:
PpacD365AppName                PpacPackageName                InstalledVersion    UpdateAvailable Status
---------------                ---------------                ----------------    --------------- ------
Business Copilot AI            msdyn_BusinessCopilotAIAnchor  1.0.0.23            True            Installed
Dual-write core solution       DualWriteCoreAnchor            1.0.24062.2         True            Installed
Dynamics 365 ChannelExperienc… msdyn_ChannelExperienceAppsAn… 1.0.24074.1004      True            Installed
Dynamics 365 ContextualHelp    msdyn_ContextualHelpAnchor     1.0.0.22            True            Installed

### EXAMPLE 8
```
$appIds = @(Get-BapEnvironmentD365App -EnvironmentId *test* -UpdatesOnly | Select-Object -ExpandProperty PpacD365AppId)
```

PS C:\\\> Invoke-BapEnvironmentInstallD365App -EnvironmentId *test* -D365AppId $appIds

This will query the environment for installed only D365 Apps.
It will filter the output to only containing those who have an update available.
It will persist the PackageIds for each D365 App, into an array.
It will invoke the installation process using the Invoke-BapEnvironmentInstallD365App cmdlet.

### EXAMPLE 9
```
Get-BapEnvironmentD365App -EnvironmentId *test* -AsExcelOutput
```

This will query the environment for ALL available D365 Apps.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

This can be obtained from the Get-BapEnvironment cmdlet

Wildcard is supported

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
Name of the D365 App that you are looking for

It supports wildcard searching, which is validated against the following properties:
* PpacD365AppName / AppName / ApplicationName
* PpacPackageName / PackageName / UniqueName

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

### -Status
Instruct the cmdlet which install states that you want to have included in the output

The default value is: "All"

Valid values:
* "All"
* "Installed"
* "InstallFailed"
* "None"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: All
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
Position: 4
Default value: Emea
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeAll
Instruction to include all D365 Apps in the output, regardless of their install state

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

### -UpdatesOnly
Instruct the cmdlet to only output D365 Apps that has an update available

Makes it easier to fully automate the update process of a given environment

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
