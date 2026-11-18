<!--
topic: d365bap.tools.Operations
keywords: operations, async, long running, correlation id, wait, poll, history, d365 operation
-->

# Operations

Platform work - version updates, platform updates, app installs - runs asynchronously, and the module follows one pattern for all of it.

An Invoke-* command starts the operation, the operation appears in a history with a correlation id, and Wait-PpacD365Operation blocks until it reaches a terminal state.

## Start

- Invoke-BapEnvironmentInstallD365App / Invoke-PpacD365AppInstall - install or update D365 apps.
- Invoke-PpacD365VersionUpdate - apply a finance and operations version.
- Invoke-PpacD365PlatformUpdate - apply a platform update.

Capture the correlation id of the started operation for the next step.

## Poll

- Get-PpacD365OperationHistory - the operation history of one environment, the source of truth for what is running.
- Get-BapEnvironmentOperation - environment life cycle operations.

## Wait

Wait-PpacD365Operation polls the history for one exact correlation id (case-insensitive) until it succeeds or fails:

```pwsh
$operation = Invoke-PpacD365VersionUpdate -EnvironmentId "es-ude-motz-01" -Version "10.0.39"
Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId $operation.CorrelationId -TimeoutMinutes 90
```

The environment parameter accepts an environment name, a PPAC environment GUID or a legacy LCS id. Combined operations also check every listed package: success requires the operation AND all packages completed. The known terminal states are Succeeded, Failed and Canceled.

A timeout (default 60 minutes, 0 means wait indefinitely) stops the polling only - the server operation keeps running, and you can call Wait-PpacD365Operation again with the same correlation id.

## Reading the result

The wait returns a result object with the operation status, Success, TimedOut, Duration and the per-package statuses. On failure it also carries the operation errors for that correlation id, the same records that Get-UnifiedEnvironmentOperationError returns. Inspect them before retrying, they name the failing step.

The module never cancels a running operation for you. If an operation must be stopped, do it from the PPAC portal.
