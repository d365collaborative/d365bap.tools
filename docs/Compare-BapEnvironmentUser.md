---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Compare-BapEnvironmentUser

## SYNOPSIS
Compare the environment users

## SYNTAX

```
Compare-BapEnvironmentUser [-SourceEnvironmentId] <String> [-DestinationEnvironmentId] <String> [-ShowDiffOnly]
 [-IncludeAppIds] [-AsExcelOutput] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to compare 2 x environments, with one as a source and the other as a destination

It will only look for users on the source, and use this as a baseline against the destination

## EXAMPLES

### EXAMPLE 1
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test*
```

This will get all system users from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will exclude those with ApplicationId filled.

Sample output:
Email                          Name                           PpacAppId            SourceId        DestinationId
-----                          ----                           ---------            --------        -------------
aba@temp.com                   Austin Baker                                        f85bcd69-ef7...
5aaac0ec-a...
ade@temp.com                   Alex Denver                                         39309a5c-767...
1d521227-4...

### EXAMPLE 2
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -IncludeAppIds
```

This will get all system users from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will include those with ApplicationId filled.

Sample output:
Email                          Name                           AppId                SourceId        DestinationId
-----                          ----                           -----                --------        -------------
aba@temp.com                   Austin Baker                                        f85bcd69-ef7...
5aaac0ec-a...
ade@temp.com                   Alex Denver                                         39309a5c-767...
1d521227-4...
AIBuilder_StructuredML_Prod...
# AIBuilder_StructuredML_Pr...
be5f0473-6b57-40f...
4d86d7d3-cb5...
9a2a59ac-6...
AIBuilderProd@onmicrosoft.c...
# AIBuilderProd                ef32e2a3-262a-44e...
4386d7d3-cb5...
902a59ac-6...

### EXAMPLE 3
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -IncludeAppIds -ShowDiffOnly
```

This will get all system users from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will include those with ApplicationId filled.
It will only output the users that is missing in the destionation environment.

Sample output:
Email                          Name                           AppId                SourceId        DestinationId
-----                          ----                           -----                --------        -------------
d365-scm-operationdataservi...
d365-scm-operationdataservi...
986556ed-a409-433...
5e077e6a-a0c...
Missing
d365-scm-operationdataservi...
d365-scm-operationdataservi...
14e80222-1878-455...
183ec023-9cc...
Missing
def@temp.com                   Dustin Effect                                       01e37132-0a4...
Missing

### EXAMPLE 4
```
Compare-BapEnvironmentD365App -SourceEnvironmentId *uat* -DestinationEnvironmentId *test* -AsExcelOutput
```

This will get all system users from the Source Environment.
It will iterate over all of them, and validate against the Destination Environment.
It will exclude those with ApplicationId filled.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -SourceEnvironmentId
Environment Id of the source environment that you want to utilized as the baseline for the compare

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

### -DestinationEnvironmentId
Environment Id of the destination environment that you want to validate against the baseline (source)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowDiffOnly
Instruct the cmdlet to only output the differences that are not aligned between the source and destination

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

### -IncludeAppIds
Instruct the cmdlet to also include the users with the ApplicationId property filled

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
