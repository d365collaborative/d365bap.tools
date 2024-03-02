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
Get-BapEnvironmentD365App [-EnvironmentId] <String> [[-Name] <String>] [[-InstallState] <String>]
 [[-GeoRegion] <String>] [-UpdatesOnly] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
This enables the user to analyze and validate the current D365 Apps and their state, on a given environment

It can show all available D365 Apps - including their InstallState

It can show only installed D365 Apps

It can show only installed D365 Apps, with available updates

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will query the environment for ALL available D365 Apps.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:

PackageId                            PackageName                    AvailableVersion    InstalledVersion    UpdateAvailable
---------                            -----------                    ----------------    ----------------    ---------------
cea6753e-9c74-4aa9-85a1-5869105115d3 msdyn_ExportControlAnchor      1.0.2553.1          N/A
ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24019.1005      True
b1676368-b448-4fbd-a238-9b6ddc36be81 SharePointFormProcessing       202209.5.2901.0     N/A
1c0a1237-9408-4b99-9fec-39696d99287b msdyn_AppProfileManagerAnchor  10.1.24021.1005     10.1.24021.1005     False
9f4c778b-2f0b-416f-8166-e96da680ffb2 mpa_AwardsAndRecognition       1.0.0.32            N/A
6ce2d70e-78bf-4ff6-85ed-1bd63d4ab444 ExportToDataLakeCoreAnchor     1.0.0.1             1.0.0.1             False

### EXAMPLE 2
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed
```

This will query the environment for installed only D365 Apps.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:
PackageId                            PackageName                    AvailableVersion    InstalledVersion    UpdateAvailable
---------                            -----------                    ----------------    ----------------    ---------------
ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24019.1005      True
1c0a1237-9408-4b99-9fec-39696d99287b msdyn_AppProfileManagerAnchor  10.1.24021.1005     10.1.24021.1005     False
6ce2d70e-78bf-4ff6-85ed-1bd63d4ab444 ExportToDataLakeCoreAnchor     1.0.0.1             1.0.0.1             False

### EXAMPLE 3
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState None
```

This will query the environment for NON-installed only D365 Apps.
It will output all details available for the D365 Apps.

Sample output:
PackageId                            PackageName                    AvailableVersion    InstalledVersion    UpdateAvailable
---------                            -----------                    ----------------    ----------------    ---------------
cea6753e-9c74-4aa9-85a1-5869105115d3 msdyn_ExportControlAnchor      1.0.2553.1          N/A
b1676368-b448-4fbd-a238-9b6ddc36be81 SharePointFormProcessing       202209.5.2901.0     N/A
9f4c778b-2f0b-416f-8166-e96da680ffb2 mpa_AwardsAndRecognition       1.0.0.32            N/A

### EXAMPLE 4
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "*ProviderAnchor*"
```

This will query the environment for ALL D365 Apps.
It will filter the output to only those who match the search pattern "*ProviderAnchor*".
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.

Sample output:
PackageId                            PackageName                    AvailableVersion    InstalledVersion    UpdateAvailable
---------                            -----------                    ----------------    ----------------    ---------------
c0cb37fd-d7f4-40f2-8592-64ec71a2c508 msft_ConnectorProviderAnchor   9.0.0.1618          9.0.0.1618          False

### EXAMPLE 5
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -UpdatesOnly
```

This will query the environment for ALL available D365 Apps.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
It will filter the output to only containing those who have an update available.

Sample output:
PackageId                            PackageName                    AvailableVersion    InstalledVersion    UpdateAvailable
---------                            -----------                    ----------------    ----------------    ---------------
ea8d3b2f-ede2-46b4-900d-ed02c81c44fd AgentProductivityToolsAnchor   9.2.24021.1005      9.2.24019.1005      True

### EXAMPLE 6
```
$appIds = @(Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed -UpdatesOnly | Select-Object -ExpandProperty PackageId)
```

PS C:\\\> Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId $appIds

This will query the environment for installed only D365 Apps.
It will filter the output to only containing those who have an update available.
It will persist the PackageIds for each D365 App, into an array.
It will invoke the installation process using the Invoke-BapEnvironmentInstallD365App cmdlet.

### EXAMPLE 7
```
Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
```

This will query the environment for ALL available D365 Apps.
It will compare available vs installed D365 Apps, and indicate whether an update is available of not.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

This can be obtained from the Get-BapEnvironment cmdlet

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
Name of the D365 App / Package that you are looking for

It supports wildcard searching, which is validated against the following properties:
* AppName / ApplicationName
* PackageName / UniqueName

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

### -InstallState
Instruct the cmdlet which install states that you want to have included in the output

The default value is: "All"

Valid values:
* "All"
* "Installed"
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

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
