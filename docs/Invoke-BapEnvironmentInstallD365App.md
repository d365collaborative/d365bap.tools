---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-BapEnvironmentInstallD365App

## SYNOPSIS
Invoke the installation of a D365 App in a given environment

## SYNTAX

```
Invoke-BapEnvironmentInstallD365App [-EnvironmentId] <String> [-PackageId] <String[]>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the invocation of the installation process against the PowerPlatform API (https://api.powerplatform.com)

The cmdlet will keep requesting the status of all invoked installations, until they all have a NON "Running" state

It will request this status every 60 seconds

## EXAMPLES

### EXAMPLE 1
```
Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId 'be69fc64-7393-4c3c-8908-2a1c2e53aef9','6defa8de-87f9-4478-8f9a-a7d685394e24'
```

This will install the 2 x D365 Apps, based on the Ids supplied.
It will run the cmdlet and have it get the status of the installation progress until all D365 Apps have been fully installed.

Sample output (Install initialized):
status  createdDateTime     lastActionDateTime  error statusMessage operationId
------  ---------------     ------------------  ----- ------------- -----------
Running 02/03/2024 13.42.07 02/03/2024 13.42.16                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Running 02/03/2024 13.42.09 02/03/2024 13.42.12                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

Sample output (Partly succeeded installation):
status    createdDateTime     lastActionDateTime  error statusMessage operationId
------    ---------------     ------------------  ----- ------------- -----------
Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Running   02/03/2024 13.42.09 02/03/2024 13.45.55                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

Sample output (Completely succeeded installation):
status    createdDateTime     lastActionDateTime  error statusMessage operationId
------    ---------------     ------------------  ----- ------------- -----------
Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Succeeded 02/03/2024 13.42.09 02/03/2024 13.48.26                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

### EXAMPLE 2
```
$appIds = @(Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed -UpdatesOnly | Select-Object -ExpandProperty PackageId)
PS C:\> Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId $appIds
```

This will find all D365 Apps that has a pending update available.
It will gather the Ids into an array.
It will run the cmdlet and have it get the status of the installation progress until all D365 Apps have been fully installed.

Sample output (Install initialized):
status  createdDateTime     lastActionDateTime  error statusMessage operationId
------  ---------------     ------------------  ----- ------------- -----------
Running 02/03/2024 13.42.07 02/03/2024 13.42.16                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Running 02/03/2024 13.42.09 02/03/2024 13.42.12                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

Sample output (Partly succeeded installation):
status    createdDateTime     lastActionDateTime  error statusMessage operationId
------    ---------------     ------------------  ----- ------------- -----------
Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Running   02/03/2024 13.42.09 02/03/2024 13.45.55                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

Sample output (Completely succeeded installation):
status    createdDateTime     lastActionDateTime  error statusMessage operationId
------    ---------------     ------------------  ----- ------------- -----------
Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Succeeded 02/03/2024 13.42.09 02/03/2024 13.48.26                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

### EXAMPLE 3
```
$apps = @(Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed -UpdatesOnly)
PS C:\> Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId $apps.PackageId
```

This will find all D365 Apps that has a pending update available.
It will gather the Ids into an array.
It will run the cmdlet and have it get the status of the installation progress until all D365 Apps have been fully installed.

Sample output (Install initialized):
status  createdDateTime     lastActionDateTime  error statusMessage operationId
------  ---------------     ------------------  ----- ------------- -----------
Running 02/03/2024 13.42.07 02/03/2024 13.42.16                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Running 02/03/2024 13.42.09 02/03/2024 13.42.12                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

Sample output (Partly succeeded installation):
status    createdDateTime     lastActionDateTime  error statusMessage operationId
------    ---------------     ------------------  ----- ------------- -----------
Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Running   02/03/2024 13.42.09 02/03/2024 13.45.55                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

Sample output (Completely succeeded installation):
status    createdDateTime     lastActionDateTime  error statusMessage operationId
------    ---------------     ------------------  ----- ------------- -----------
Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
Succeeded 02/03/2024 13.42.09 02/03/2024 13.48.26                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d

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

### -PackageId
The id of the package(s) that you want to have Installed

It supports id of current packages, with updates available and new D365 apps

It support an array as input, so it can invoke multiple D365 App installations

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
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
