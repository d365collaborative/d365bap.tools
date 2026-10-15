---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-PpacD365AppInstall

## SYNOPSIS
Installs or updates D365 applications in the environment.

## SYNTAX

```
Invoke-PpacD365AppInstall [-EnvironmentId] <String> [-D365App] <String[]> [[-PayloadValue] <String>]
 [[-PollIntervalSeconds] <Int32>] [[-TimeoutMinutes] <Int32>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to install or update D365 applications in the environment as it would be done in Power Platform Admin Center (PPAC).

Mimics the behavior of 'pac app-management install-application-package --unique-name':
POST https://api.powerplatform.com/appmanagement/environments/{environmentId}/applicationPackages/{uniqueName}/install?api-version=2024-10-01
with body '{"payloadValue":"..."}' (or '{}' when no payload is needed).

The same endpoint handles both fresh installs (state 'None') and updates of already installed apps.

Returns one result object per requested app with the final operation status.

## EXAMPLES

### EXAMPLE 1
```
Invoke-PpacD365AppInstall -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -D365App "Invoice Capture for Dynamics 365 Finance"
```

This will install the "Invoice Capture for Dynamics 365 Finance" application in the environment.

### EXAMPLE 2
```
Invoke-PpacD365AppInstall -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -D365App "msdyn_FnoInvoiceCaptureAnchor"
```

This will install the "Invoice Capture for Dynamics 365 Finance" application in the environment.
It will use the unique name of the application (msdyn_FnoInvoiceCaptureAnchor) to find the application and install it.

### EXAMPLE 3
```
Invoke-PpacD365AppInstall -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -D365App "MicrosoftOperationsVEAnchor","msdyn_FnoInvoiceCaptureAnchor"
```

This will install the "Microsoft Operations VE" and "Invoice Capture for Dynamics 365 Finance" applications in the environment.
It will use the unique name of the D365 applications to find the applications and install them.
It will start the installation of both applications, and then wait for the installation process to finish.

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

### -D365App
The name, unique name or package name of the D365 application you want to install in the environment.

Supports single or multiple application names.

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

### -PayloadValue
Optional payload value sent as '{"payloadValue":"..."}' in the install request body.

Required by some apps with a custom install experience (e.g.
Finance and Operations Provisioning App).
Omit for regular installs / updates.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PollIntervalSeconds
Seconds to wait between each status poll against the operations endpoint.

Defaults to 60 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutMinutes
Maximum time to wait for all installations to reach a terminal state (Succeeded / Failed / Canceled) before giving up polling.

Defaults to 120 minutes.
Use 0 to wait indefinitely (not recommended for automation).

When the timeout expires the cmdlet stops polling, warns, and returns the last known statuses so the caller can decide how to proceed.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 120
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
