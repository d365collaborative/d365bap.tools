<#
.SYNOPSIS
    Checks release publication offline.

.DESCRIPTION
    Injects upload responses to verify recovery, bounded delays, and propagation
    of permanent failures while keeping the staged package and credentials fixed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$publisher = Join-Path $PSScriptRoot 'Publish-ModuleWithRetry.ps1'
$state = @{}

function Publish-Module {
	[CmdletBinding()]
	param([string] $Path, [string] $NuGetApiKey, [switch] $Force, [string] $Repository)

	if ($Path -cne 'staged/d365bap.tools' -or $NuGetApiKey -cne 'test-key' -or
		-not $Force -or $Repository -cne $state.repository -or $PSBoundParameters.ErrorAction -ne 'Stop') {
		throw 'Publication changed the package, credentials, repository, or error handling.'
	}
	$index = $state.calls
	$state.calls++
	if ($index -ge $state.responses.Count) { throw 'Unexpected extra upload attempt.' }
	$response = $state.responses[$index]
	if ($response -eq 'success') { return }
	$message = if ($response -match '^\d{3}$') {
		"Failed to publish module 'd365bap.tools': 'nuget.exe failed to push Response status code does not indicate success: $response (Injected failure). '."
	}
	else { $response }
	Write-Error -Message $message
}

function Start-Sleep {
	param([int] $Seconds)
	$state.delays.Add($Seconds)
}

$scenarios = @(
	@{ Name = 'Immediate success'; Responses = @('success'); Calls = 1; Delays = @() },
	@{ Name = 'Reported Gallery 404 recovers'; Responses = @('404', 'success'); Calls = 2; Delays = @(10) },
	@{ Name = 'Success on final attempt'; Responses = @('404', '502', '503', 'success'); Calls = 4; Delays = @(10, 20, 40) },
	@{ Name = 'Persistent Gallery 404 fails'; Responses = @('404', '404', '404', '404'); Calls = 4; Delays = @(10, 20, 40); Failure = '404' },
	@{ Name = 'Permanent error after transient failure'; Responses = @('503', '403'); Calls = 2; Delays = @(10); Failure = '403' },
	@{ Name = 'Custom repository 404 fails immediately'; Repository = 'PrivateFeed'; Responses = @('404'); Calls = 1; Delays = @(); Failure = '404' },
	@{ Name = 'Unrelated number does not trigger retries'; Responses = @('Invalid package version 0.0.503'); Calls = 1; Delays = @(); Failure = 'Invalid package version' }
)
foreach ($status in @('408', '429', '500', '502', '503', '504')) {
	$scenarios += @{ Name = "HTTP $status recovers"; Responses = @($status, 'success'); Calls = 2; Delays = @(10) }
}
foreach ($status in @('400', '401', '403', '409', '422')) {
	$scenarios += @{ Name = "HTTP $status fails immediately"; Responses = @($status); Calls = 1; Delays = @(); Failure = $status }
}

foreach ($scenario in $scenarios) {
	$state.calls = 0
	$state.delays = [Collections.Generic.List[int]]::new()
	$state.responses = $scenario.Responses
	$state.repository = if ($scenario.Repository) { $scenario.Repository } else { 'PSGallery' }
	$caught = $null
	try { & $publisher -Path 'staged/d365bap.tools' -ApiKey 'test-key' -Repository $state.repository }
	catch { $caught = $_ }

	if ($state.calls -ne $scenario.Calls -or ($state.delays -join ',') -cne ($scenario.Delays -join ',')) {
		throw "$($scenario.Name): unexpected upload count ($($state.calls)) or delays ($($state.delays -join ','))."
	}
	if ($scenario.Failure) {
		if ($null -eq $caught -or $caught.Exception.Message -notlike "*$($scenario.Failure)*") {
			throw "$($scenario.Name): original upload error did not propagate: $caught"
		}
	}
	elseif ($null -ne $caught) { throw "$($scenario.Name): $caught" }
	Write-Output "PASS: $($scenario.Name)"
}

Write-Output 'Module publication regression checks passed.'
