
<#
    .SYNOPSIS
        Wait for a D365 operation to reach a terminal state.

    .DESCRIPTION
        Polls operation history for the exact correlation ID until it
        succeeds, fails, or times out. Combined deployments also require
        every listed package to complete. A timeout stops polling only; the
        server operation keeps running.

    .PARAMETER EnvironmentId
        The environment to wait in. Accepts a name, PPAC GUID, or LCS ID.

    .PARAMETER CorrelationId
        The exact operation correlation ID to wait for. Case-insensitive;
        others are ignored.

    .PARAMETER TimeoutMinutes
        Minutes to wait for a terminal state.

        Default: 60. Use 0 to wait indefinitely.

    .PARAMETER PollIntervalSeconds
        Seconds between status polls.

        Default: 15.

    .EXAMPLE
        PS C:\> Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId "220379e3-8b13-4c3c-8988-d17e85071738" -TimeoutMinutes 60 -PollIntervalSeconds 15

        Waits up to 60 minutes, polling every 15 seconds. Success needs the
        operation and every listed package completed.

    .EXAMPLE
        PS C:\> Wait-PpacD365Operation -EnvironmentId "es-ude-motz-01" -CorrelationId "f6adaf07-4930-4399-92f2-0d3944065785"

        Waits with default timeout and poll interval. On failure the result
        carries the matching operation errors.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Wait-PpacD365Operation {
	[CmdletBinding()]
	[OutputType('System.Object')]
	param (
		[Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[Parameter (Mandatory = $true)]
		[string] $CorrelationId,

		[ValidateRange(0, 4320)]
		[int] $TimeoutMinutes = 60,

		[ValidateRange(1, 3600)]
		[int] $PollIntervalSeconds = 15
	)

	begin {
		$envObj = Get-UnifiedEnvironment `
			-EnvironmentId $EnvironmentId `
			-SkipVersionDetails | `
			Select-Object -First 1

		if ($null -eq $envObj) {
			$messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		$correlationIdString = "$CorrelationId".Trim()
		$operationFailedStatuses = @('Failed', 'Canceled', 'Cancelled')
		$packageFailedStatuses = @('Failed', 'Canceled', 'Cancelled')
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$startTime = Get-Date
		$pollDeadline = if ($TimeoutMinutes -gt 0) { $startTime.AddMinutes($TimeoutMinutes) } else { [datetime]::MaxValue }

		$matchedOperation = $null
		$expectedPackages = @()
		$packageResults = @()
		$timedOut = $false
		$success = $false

		do {
			$history = Get-PpacD365OperationHistory -EnvironmentId $envObj.PpacEnvId

			$matchedOperation = @($history | Where-Object { "$($_.CorrelationId)" -eq $correlationIdString } | Sort-Object -Property Modified -Descending) | Select-Object -First 1

			if ($null -ne $matchedOperation) {
				$expectedPackages = @()

				$rawProperties = $matchedOperation.msprov_operationproperties
				if (-not [string]::IsNullOrWhiteSpace("$rawProperties")) {
					try {
						if (Test-Json -Json "$rawProperties" -ErrorAction SilentlyContinue) {
							$parsedProperties = "$rawProperties" | ConvertFrom-Json -Depth 10 -ErrorAction Stop
							if ($null -ne $parsedProperties.PackageDetailsList) {
								$expectedPackages = @($parsedProperties.PackageDetailsList)
							}
						}
					}
					catch {
						Write-PSFMessage -Level Verbose -Message "Could not parse operation properties for correlation ID <c='em'>$correlationIdString</c>. Continuing without package checks."
						$expectedPackages = @()
					}
				}

				$packageResults = @()

				if ($expectedPackages.Count -gt 0) {
					$allPackages = Get-UnifiedEnvironmentPackage -EnvironmentId $envObj.PpacEnvId

					foreach ($expected in $expectedPackages) {
						$expectedId = "$($expected.Id)"
						$expectedName = "$($expected.PackageName)"

						$matchedPackage = @($allPackages | Where-Object { "$($_.PackageId)" -eq $expectedId }) | Select-Object -First 1

						if ($null -eq $matchedPackage) {
							$packageResults += [PSCustomObject]@{
								PackageId   = $expectedId
								PackageName = $expectedName
								Status      = 'NotFound'
								State       = $null
							}
						}
						else {
							$packageResults += [PSCustomObject]@{
								PackageId   = "$($matchedPackage.PackageId)"
								PackageName = "$($matchedPackage.Name)"
								Status      = "$($matchedPackage.Status)"
								State       = "$($matchedPackage.State)"
							}
						}
					}
				}

				$operationStatus = "$($matchedOperation.Status)"

				$operationSucceeded = $operationStatus -eq 'Succeeded'
				$operationFailed = $operationFailedStatuses -contains $operationStatus

				$packagesCompleted = $true
				$packagesFailed = $false

				if ($expectedPackages.Count -gt 0) {
					$packagesCompleted = ($packageResults.Count -eq $expectedPackages.Count) -and `
					(@($packageResults | Where-Object { $_.Status -eq 'Completed' }).Count -eq $expectedPackages.Count)
					$packagesFailed = @($packageResults | Where-Object { $packageFailedStatuses -contains $_.Status }).Count -gt 0
				}

				if ($operationSucceeded -and $packagesCompleted) {
					$success = $true
					break
				}

				if ($operationFailed -or $packagesFailed) {
					$success = $false
					break
				}

				Write-Progress -Id 1 `
					-Activity "Waiting for D365 operation '$correlationIdString' in '$($envObj.PpacEnvName)'" `
					-Status "Operation status: $operationStatus. Packages completed: $(@($packageResults | Where-Object { $_.Status -eq 'Completed' }).Count) of $($expectedPackages.Count)." `
					-PercentComplete -1
			}
			else {
				Write-Progress -Id 1 `
					-Activity "Waiting for D365 operation '$correlationIdString' in '$($envObj.PpacEnvName)'" `
					-Status "Operation not visible yet. Waiting for it to appear in the operation history." `
					-PercentComplete -1
			}

			if ((Get-Date) -ge $pollDeadline) {
				$timedOut = $true
				break
			}

			$remainingSeconds = ($pollDeadline - (Get-Date)).TotalSeconds
			if ($remainingSeconds -le 0) {
				$timedOut = $true
				break
			}

			$sleepSeconds = [Math]::Min($PollIntervalSeconds, [Math]::Max(1, [Math]::Floor($remainingSeconds)))
			Start-Sleep -Seconds ([int]$sleepSeconds)
		} while ($true)

		Write-Progress -Id 1 -Completed -Activity "Waiting for D365 operation '$correlationIdString' in '$($envObj.PpacEnvName)'"

		$errors = @()

		if ($null -ne $matchedOperation -and -not $success) {
			$operationStatus = "$($matchedOperation.Status)"
			$packagesFailed = @($packageResults | Where-Object { $packageFailedStatuses -contains $_.Status }).Count -gt 0

			if (($operationFailedStatuses -contains $operationStatus) -or $packagesFailed) {
				$allErrors = Get-UnifiedEnvironmentOperationError -EnvironmentId $envObj.PpacEnvId -MaxResults 100
				$errors = @($allErrors | Where-Object { "$($_.CorrelationId)" -eq $correlationIdString })
			}
		}

		$endTime = Get-Date
		$duration = New-TimeSpan -Start $startTime -End $endTime

		if ($timedOut -and -not $success) {
			$messageString = "Waiting for operation with correlation ID <c='em'>$correlationIdString</c> timed out after <c='em'>$TimeoutMinutes minute(s)</c>. Stopping without cancelling the server operation."
			Write-PSFMessage -Level Warning -Message $messageString
		}

		[PSCustomObject]@{
			PSTypeName      = 'D365Bap.Tools.PpacD365OperationWaitResult'
			EnvironmentId   = "$($envObj.PpacEnvId)"
			EnvironmentName = "$($envObj.PpacEnvName)"
			CorrelationId   = $correlationIdString
			OperationId     = if ($null -ne $matchedOperation) { "$($matchedOperation.Id)" } else { $null }
			OperationName   = if ($null -ne $matchedOperation) { "$($matchedOperation.Name)" } else { $null }
			Status          = if ($null -ne $matchedOperation) { "$($matchedOperation.Status)" } else { 'NotFound' }
			OperationState  = if ($null -ne $matchedOperation) { "$($matchedOperation.State)" } else { $null }
			Success         = [bool]$success
			TimedOut        = [bool]$timedOut
			StartedOn       = if ($null -ne $matchedOperation) { $matchedOperation.StartedOn } else { $null }
			Duration        = $duration
			Packages        = $packageResults
			Errors          = $errors
		}
	}

	end {
	}
}
