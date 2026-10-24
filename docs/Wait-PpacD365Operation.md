---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Wait-PpacD365Operation

## SYNOPSIS
Wait for a D365 operation to reach a terminal state.

## SYNTAX

```
Wait-PpacD365Operation [-EnvironmentId] <String> [-CorrelationId] <String> [[-TimeoutMinutes] <Int32>]
 [[-PollIntervalSeconds] <Int32>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Polls Get-PpacD365OperationHistory for the exact correlation ID until the
operation succeeds, fails, or the timeout expires.

For combined deployments the operation payload lists every package in
PackageDetailsList.
Each listed package is checked through
Get-UnifiedEnvironmentPackage.
Success is only returned when the
operation succeeded and every associated package completed.

On failure, matching details from Get-UnifiedEnvironmentOperationError
are included in the result.

On timeout the cmdlet stops waiting and returns the last known state.
The server operation is never cancelled.

## EXAMPLES

### EXAMPLE 1
```
Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId "220379e3-8b13-4c3c-8988-d17e85071738" -TimeoutMinutes 60 -PollIntervalSeconds 15
```

This will wait up to 60 minutes for the operation with the specified correlation ID to complete.
It polls the operation history every 15 seconds and checks every package listed in the operation payload.
It returns success only when the operation succeeded and all associated packages completed.

### EXAMPLE 2
```
Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId "f6adaf07-4930-4399-92f2-0d3944065785"
```

This will wait for the operation with the specified correlation ID using the default timeout and poll interval.
If the operation failed, the result includes the matching entries from Get-UnifiedEnvironmentOperationError.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -CorrelationId
The exact correlation ID of the operation to wait for.

Matching is case-insensitive and exact.
Unrelated operations with
different correlation IDs are ignored.

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

### -TimeoutMinutes
Maximum time to wait for the operation to reach a terminal state.

Defaults to 60 minutes.
Use 0 to wait indefinitely (not recommended for automation).

When the timeout expires the cmdlet stops polling and returns the last
known state with TimedOut set to true.
The server operation keeps running.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -PollIntervalSeconds
Seconds to wait between each status poll.

Defaults to 15 seconds.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 15
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
