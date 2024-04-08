---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentSolution

## SYNOPSIS
Get PowerPlatform / Dataverse Solution from the environment

## SYNTAX

```
Get-BapEnvironmentSolution [-EnvironmentId] <String> [[-SolutionId] <String>] [-IncludeManaged]
 [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to list solutions and their meta data, on a given environment

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
```

This will query the specific environment.
It will only list Unmanaged / NON-Managed solutions.

Sample output:

SolutionId                           Name                           IsManaged SystemName           Description
----------                           ----                           --------- ----------           -----------
fd140aae-4df4-11dd-bd17-0019b9312238 Active Solution                False     Active               Placeholder solutio…

### EXAMPLE 2
```
Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged
```

This will query the specific environment.
It will list all solutions.

Sample output:

SolutionId                           Name                           IsManaged SystemName           Description
----------                           ----                           --------- ----------           -----------
169edc7d-5f1e-4ee4-8b5c-135b3ba82ea3 Access Team                    True      AccessTeam           Access Team solution
fd140aae-4df4-11dd-bd17-0019b9312238 Active Solution                False     Active               Placeholder solutio…
458c32fb-4476-4431-97cb-49cfd069c31d Activities                     True      msdynce_Activities   Dynamics 365 worklo…
7553bb8a-fc5e-424c-9698-113958c28c98 Activities Patch               True      msdynce_ActivitiesP… Patch for Dynamics …
3ac10775-0808-42e0-bd23-83b6c714972f ActivitiesInfra Solution Anch… True      msft_ActivitiesInfr… ActivitiesInfra Sol…

### EXAMPLE 3
```
Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged
```

This will query the specific environment.
It will list all solutions, unmanaged / managed.

Sample output:

SolutionId                           Name                           IsManaged SystemName           Description
----------                           ----                           --------- ----------           -----------
169edc7d-5f1e-4ee4-8b5c-135b3ba82ea3 Access Team                    True      AccessTeam           Access Team solution
fd140aae-4df4-11dd-bd17-0019b9312238 Active Solution                False     Active               Placeholder solutio…
458c32fb-4476-4431-97cb-49cfd069c31d Activities                     True      msdynce_Activities   Dynamics 365 worklo…
7553bb8a-fc5e-424c-9698-113958c28c98 Activities Patch               True      msdynce_ActivitiesP… Patch for Dynamics …
3ac10775-0808-42e0-bd23-83b6c714972f ActivitiesInfra Solution Anch… True      msft_ActivitiesInfr… ActivitiesInfra Sol…

### EXAMPLE 4
```
Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged -SolutionId 3ac10775-0808-42e0-bd23-83b6c714972f
```

This will query the specific environment.
It will list all solutions, unmanaged / managed.
It will search for the 3ac10775-0808-42e0-bd23-83b6c714972f solution.

Sample output:

SolutionId                           Name                           IsManaged SystemName           Description
----------                           ----                           --------- ----------           -----------
3ac10775-0808-42e0-bd23-83b6c714972f ActivitiesInfra Solution Anch… True      msft_ActivitiesInfr… ActivitiesInfra Sol…

### EXAMPLE 5
```
Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged -AsExcelOutput
```

This will query the specific environment.
It will list all solutions, unmanaged / managed.
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

### -SolutionId
The id of the solution that you want to work against

Leave blank to get all solutions

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeManaged
Instruct the cmdlet to include all managed solution

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
