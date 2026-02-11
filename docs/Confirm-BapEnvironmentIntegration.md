---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Confirm-BapEnvironmentIntegration

## SYNOPSIS
Test the integration status

## SYNTAX

```
Confirm-BapEnvironmentIntegration [-EnvironmentId] <String> [-AsExcelOutput]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Invokes the validation of the PowerPlatform integration, from the Dataverse perspective

If it returns an output, the Dataverse is fully connected to the D365FO environment

## EXAMPLES

### EXAMPLE 1
```
Confirm-BapEnvironmentIntegration -EnvironmentId *uat*
```

This will invoke the validation from the Dataverse environment.
It will only output details if the environment is fully connected and working.

Sample output:
LinkedAppLcsEnvId                    LinkedAppLcsEnvUri                                 IsUnifiedDatabase TenantId
-----------------                    ------------------                                 ----------------- --------
0e52661c-0225-4621-b1b4-804712cf6d9a https://new-test.sandbox.operations.eu.dynamics...
False             8ccb796b-7...

### EXAMPLE 2
```
Confirm-BapEnvironmentIntegration -EnvironmentId *uat* -AsExcelOutput
```

This will invoke the validation from the Dataverse environment.
It will only output details if the environment is fully connected and working.
Will output all details into an Excel file, that will auto open on your machine.

The excel file will be empty if the integration isn't working.

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
