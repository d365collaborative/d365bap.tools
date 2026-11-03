<#
    .SYNOPSIS
        Checks pinned prek restore and reinstall behavior.

    .DESCRIPTION
        Runs Install-Prek.ps1 against a fixture executable and a fake pip so the
        cache-hit, cache-miss, version-mismatch, and install-failure paths stay
        deterministic without a network or a prek install.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('prek-install-' + [guid]::NewGuid().ToString('N'))
$installer = Join-Path $PSScriptRoot 'Install-Prek.ps1'
$requirementsPath = Join-Path $PSScriptRoot 'ToolCacheRequirements.json'
$requirements = Get-Content -LiteralPath $requirementsPath -Raw | ConvertFrom-Json
$pin = [string]$requirements.prek

$state = @{
	TargetPath     = Join-Path $fixture 'target'
	PrekPath       = Join-Path $fixture 'target/bin/prek.ps1'
	PipCalls       = [System.Collections.Generic.List[string]]::new()
	InstallVersion = $pin
	InstallExit    = 0
}

function Assert-True([bool]$Condition, [string]$Message) {
	if (-not $Condition) { throw $Message }
}

function Write-FakePrek([string]$ReportedVersion, [int]$ExitCode = 0) {
	$directory = Split-Path -Path $state.PrekPath -Parent
	$null = New-Item -ItemType Directory -Path $directory -Force
	@(
		'[CmdletBinding()]'
		'param([Parameter(ValueFromRemainingArguments = $true)] [object[]] $Rest)'
		"Write-Output 'prek $ReportedVersion (fixture)'"
		"exit $ExitCode"
	) | Set-Content -LiteralPath $state.PrekPath -Encoding utf8
}

# Stands in for `python` so no test touches pip or the network.
function Invoke-FakePip {
	param([Parameter(ValueFromRemainingArguments = $true)] [object[]]$Rest)
	$state.PipCalls.Add(($Rest -join ' '))
	if ($state.InstallExit -ne 0) {
		$global:LASTEXITCODE = $state.InstallExit
		return
	}
	Write-FakePrek $state.InstallVersion 0
	$global:LASTEXITCODE = 0
}

function Invoke-Installer {
	$output = @(& $installer -TargetPath $state.TargetPath -PrekPath $state.PrekPath -PythonExecutable 'Invoke-FakePip' *>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Invoke-InstallerFailure([string]$Label) {
	$caught = $null
	try { $null = Invoke-Installer }
	catch { $caught = $_ }
	Assert-True ($null -ne $caught) "$Label must fail the step."
	$caught.Exception.Message
}

function Initialize-Scenario {
	$state.PipCalls.Clear()
	$state.InstallVersion = $pin
	$state.InstallExit = 0
	Remove-Item -LiteralPath $state.TargetPath -Recurse -Force -ErrorAction Ignore
}

try {
	Assert-True ($pin -match '^\d+\.\d+\.\d+$') "The prek pin must be an exact version: '$pin'."

	# A restored executable that reports the pin is used as-is.
	Initialize-Scenario
	Write-FakePrek $pin
	$result = Invoke-Installer
	Assert-True ($result.ExitCode -eq 0) "A cache hit must succeed: $($result.Output)"
	Assert-True ($state.PipCalls.Count -eq 0) "A cache hit must not run pip: $($state.PipCalls -join '; ')"
	Assert-True ($result.Output -match "Restored pinned prek $([regex]::Escape($pin))") "A cache hit must report the restored pin: $($result.Output)"
	Write-Output 'PASS: matching restored executable skips install'

	# A missing executable is installed at the exact pin.
	Initialize-Scenario
	$result = Invoke-Installer
	Assert-True ($result.ExitCode -eq 0) "A cache miss must install the pin: $($result.Output)"
	Assert-True ($state.PipCalls.Count -eq 1) "A cache miss must install once, got $($state.PipCalls.Count)."
	$installed = $state.PipCalls[0]
	Assert-True ($installed -match 'pip install' -and $installed -match "--target $([regex]::Escape($state.TargetPath))" -and $installed -match "prek==$([regex]::Escape($pin))") "The install must use the pinned package and target: $installed"
	Assert-True ($result.Output -match "Installed pinned prek $([regex]::Escape($pin))") "A cache miss must report the installed pin: $($result.Output)"
	Write-Output 'PASS: cache miss installs the exact pin'

	# A restored executable with another version is replaced by the pin.
	Initialize-Scenario
	Write-FakePrek '0.5.6'
	$result = Invoke-Installer
	Assert-True ($result.ExitCode -eq 0) "A version mismatch must reinstall the pin: $($result.Output)"
	Assert-True ($state.PipCalls.Count -eq 1) "A version mismatch must reinstall once, got $($state.PipCalls.Count)."
	Assert-True ($result.Output -match 'instead of' -and $result.Output -match 'reinstalling') "A version mismatch must be reported: $($result.Output)"
	Write-Output 'PASS: version mismatch reinstalls the pin'

	# A restored executable that reports the pin but fails is also replaced.
	Initialize-Scenario
	Write-FakePrek $pin 1
	$result = Invoke-Installer
	Assert-True ($result.ExitCode -eq 0) "A failing probe must reinstall the pin: $($result.Output)"
	Assert-True ($state.PipCalls.Count -eq 1) "A failing probe must reinstall once, got $($state.PipCalls.Count)."
	Write-Output 'PASS: failing version probe reinstalls the pin'

	# If the install still produces another version, the step fails closed.
	Initialize-Scenario
	Write-FakePrek '0.5.6'
	$state.InstallVersion = '0.5.6'
	$message = Invoke-InstallerFailure 'A pin that cannot be produced'
	Assert-True ($message -match 'Refusing to fall back' -and $message -match '0\.5\.6') "The mismatch failure must name the observed version: $message"
	Write-Output 'PASS: unreproducible pin fails closed'

	# A failed install fails the step and leaves no executable behind.
	Initialize-Scenario
	$state.InstallExit = 1
	$message = Invoke-InstallerFailure 'A failed pip install'
	Assert-True ($message -match 'failed with exit code 1') "The install failure must report the exit code: $message"
	Assert-True (-not (Test-Path -LiteralPath $state.PrekPath)) 'A failed install must not leave an executable.'
	Write-Output 'PASS: failed install fails the step'

	Write-Output 'Pinned prek install regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $fixture) {
		$resolved = (Resolve-Path -LiteralPath $fixture).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -or
			[IO.Path]::GetFileName($resolved) -notmatch '^prek-install-[0-9a-f]{32}$') {
			throw 'Unexpected fixture cleanup path.'
		}
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
