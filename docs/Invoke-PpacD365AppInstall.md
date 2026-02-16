---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Invoke-PpacD365AppInstall

## SYNOPSIS
Installs D365 applications in the environment.

## SYNTAX

```
Invoke-PpacD365AppInstall [-EnvironmentId] <String> [-D365App] <String[]> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Enables the user to install D365 applications in the environment as it would be done in Power Platform Admin Center (PPAC).

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
