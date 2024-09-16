---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentPowerApp

## SYNOPSIS
Get PowerApps from environment

## SYNTAX

```
Get-BapEnvironmentPowerApp [-EnvironmentId] <String> [[-Name] <String>] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to fetch all PowerApps from the environment

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentPowerApp -EnvironmentId *uat*
```

This will query the environment for ALL available Power Apps.
It will show both Canvas and Model-driven apps.

Sample output:
PpacPowerAppName               PowerAppType IsManaged Owner                Description
----------------               ------------ --------- -----                -----------
API Playground                 Canvas       True      alex@contoso.com
Channel Integration Framework  Model-driven True      N/A                  Bring your communication channels and bu...
CRM Hub                        Model-driven True      N/A                  Mobile app that provides core CRM functi...
Customer Service admin center  Model-driven True      N/A                  A unified app for customer service admin...
Customer Service Hub           Model-driven True      N/A                  A focused, interactive experience for ma...
Customer Service workspace     Model-driven True      N/A                  Multi-session Customer Service with Prod...

### EXAMPLE 2
```
Get-BapEnvironmentPowerApp -EnvironmentId *uat* -Name *CRM*
```

This will query the environment for ALL available Power Apps.
It will show both Canvas and Model-driven apps.
It will only show those that has "CRM" in the name.

Sample output:
PpacPowerAppName               PowerAppType IsManaged Owner                Description
----------------               ------------ --------- -----                -----------
CRM Hub                        Model-driven True      N/A                  Mobile app that provides core CRM functi...

### EXAMPLE 3
```
Get-BapEnvironmentPowerApp -EnvironmentId *uat* -AsExcelOutput
```

This will query the environment for ALL available Power Apps.
It will show both Canvas and Model-driven apps.
It will output all details into an Excel file, that will auto open on your machine.

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
Name of the Power App that you are looking for

It supports wildcard searching, which is validated against the following properties:
* PpacPowerAppName / Name / DisplayName / PpacSystemName
* PpacPowerAppName / LogicalName / UniqueName

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
