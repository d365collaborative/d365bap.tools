---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironment

## SYNOPSIS
Get environment info

## SYNTAX

```
Get-BapEnvironment [[-EnvironmentId] <String>] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to query and validate all environments that are available from inside PPAC

It utilizes the "https://api.bap.microsoft.com" REST API

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironment
```

This will query for ALL available environments.

Sample output:
PpacEnvId                            PpacEnvRegion   PpacEnvName          PpacEnvSku LinkedAppLcsEnvUri
---------                            -------------   -----------          ---------- ------------------
32c6b196-ef52-4c43-93cf-6ecba51e6aa1 europe          new-uat              Sandbox    https://new-uat.sandbox.operatio…
eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 europe          new-test             Sandbox    https://new-test.sandbox.operati…
d45936a7-0408-4b79-94d1-19e4c6e5a52e europe          new-golden           Sandbox    https://new-golden.sandbox.opera…
Default-e210bc90-e54b-4544-a9b8-b1f… europe          New Customer         Default

### EXAMPLE 2
```
Get-BapEnvironment -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will query for the specific environment.

Sample output:
PpacEnvId                            PpacEnvRegion   PpacEnvName          PpacEnvSku LinkedAppLcsEnvUri
---------                            -------------   -----------          ---------- ------------------
eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 europe          new-test             Sandbox    https://new-test.sandbox.operati…

### EXAMPLE 3
```
Get-BapEnvironment -AsExcelOutput
```

This will query for ALL available environments.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
