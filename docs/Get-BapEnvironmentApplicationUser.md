---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentApplicationUser

## SYNOPSIS
Get application users from environment

## SYNTAX

```
Get-BapEnvironmentApplicationUser [-EnvironmentId] <String> [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to fetch all application users from the environment

Utilizes the built-in "applicationusers" OData entity

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentApplicationUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will fetch all ApplicationUsers from the environment.

Sample output:
AppId                                AppName                        ApplicationUserId                    SolutionId
-----                                -------                        -----------------                    ----------
b6e52ceb-f771-41ff-bd99-917523b28eaf AIBuilder_StructuredML_Prod_Câ€¦ 3bafba76-60bf-413d-a4c4-5c49ccabfb12 bf85e0c8-aa47â€¦
21ceaf7c-054c-43f6-8b14-ef6d04b90a21 AIBuilderProd                  560c9a6c-4535-4066-a415-480d1493cf98 bf85e0c8-aa47â€¦
c76313fd-5c6f-4f1f-9869-c884fa7fe226 AppDeploymentOrchestration     d88a3535-ebf0-4b2b-ad23-90e686660a64 99aee001-009eâ€¦
29494271-7e38-4433-8bf8-06d335299a17 AriaMdlExporter                8bf8862f-5036-42b0-a4f8-1b638db7896b 99aee001-009eâ€¦

### EXAMPLE 2
```
Get-BapEnvironmentApplicationUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
```

This will fetch all ApplicationUsers from the environment.
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
