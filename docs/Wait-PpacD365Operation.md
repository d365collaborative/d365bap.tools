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
Polls operation history for the exact correlation ID until it
succeeds, fails, or times out.
Combined deployments also require
every listed package to complete.
A timeout stops polling only; the
server operation keeps running.

## EXAMPLES

### EXAMPLE 1
```
Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId "220379e3-8b13-4c3c-8988-d17e85071738" -TimeoutMinutes 60 -PollIntervalSeconds 15
```

Waits up to 60 minutes, polling every 15 seconds.
Success needs the
operation and every listed package completed.

### EXAMPLE 2
```
Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId "f6adaf07-4930-4399-92f2-0d3944065785"
```

Waits with default timeout and poll interval.
On failure the result
carries the matching operation errors.

## PARAMETERS

### -EnvironmentId
The environment to wait in.
Accepts a name, PPAC GUID, or LCS ID.

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
The exact operation correlation ID to wait for.
Case-insensitive;
others are ignored.

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
Minutes to wait for a terminal state.

Default: 60.
Use 0 to wait indefinitely.

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
Seconds between status polls.

Default: 15.

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
