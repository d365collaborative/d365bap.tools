---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentUser

## SYNOPSIS
Get users from environment

## SYNTAX

```
Get-BapEnvironmentUser [-EnvironmentId] <String> [-IncludeAppIds] [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to fetch all users from the environment

Utilizes the built-in "systemusers" OData entity

Allows the user to include all users, based on those who has the ApplicationId property filled

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentUser -EnvironmentId *uat*
```

This will fetch all oridinary users from the environment.

Sample output:
Email                          Name                           PpacAppId            PpacSystemUserId
-----                          ----                           ---------            ----------------
SYSTEM                                                                             5d2ff978-a74c-4ba4-8cc2-b4c5a23994f7
INTEGRATION                                                                        baabe592-2860-4d1a-9365-e95317372498
aba@temp.com                   Austin Baker                                        f85bcd69-ef72-45bd-a338-62670a8cef2a
ade@temp.com                   Alex Denver                                         39309a5c-7676-4c8a-b702-719fb92c5151

### EXAMPLE 2
```
Get-BapEnvironmentUser -EnvironmentId *uat* -IncludeAppIds
```

This will fetch all users from the environment.
It will include the ones with the ApplicationId property filled.

Sample output:
Email                          Name                           PpacAppId            PpacSystemUserId
-----                          ----                           ---------            ----------------
SYSTEM                                                                             5d2ff978-a74c-4ba4-8cc2-b4c5a23994f7
INTEGRATION                                                                        baabe592-2860-4d1a-9365-e95317372498
aba@temp.com                   Austin Baker                                        f85bcd69-ef72-45bd-a338-62670a8cef2a
AIBuilderProd@onmicrosoft.com  # AIBuilderProd                0a143f2d-2320-414...
c96f82b8-320f-4c5e-ac84-1831f4dc7d5f

### EXAMPLE 3
```
Get-BapEnvironmentUser -EnvironmentId *uat* -AsExcelOutput
```

This will fetch all oridinary users from the environment.
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

### -IncludeAppIds
Instruct the cmdlet to include all users that are available from the "systemusers" OData Entity

Simply includes those who has the ApplicationId property filled

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
