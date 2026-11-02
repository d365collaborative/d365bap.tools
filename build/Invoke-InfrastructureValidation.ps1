<#
.SYNOPSIS
    Runs validation infrastructure regression suites.

.DESCRIPTION
    The infrastructure-tests job in validate.yml runs this script. Every
    declared suite must exist and pass: a missing suite fails the run instead of
    silently shrinking coverage.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Keep this list in sync with the infrastructure-change patterns in
# Get-PRValidationPlan.ps1. Test-PRValidationPlan.ps1 pins both the list and
# the plan flag, so adding a suite here without teaching the plan about its
# inputs fails that regression.
$infrastructureSuite = @(
	'Test-PRValidationPlan'
	'Test-Ps1LintScope'
	'Test-CiLintPlan'
	'Test-Ps1FormatXml'
	'Test-SelectiveValidation'
	'Test-SelectedStringsHandling'
	'Test-Ps1LintCorrectness'
	'Test-Ps1LintBatch'
)

$pwsh = (Get-Process -Id $PID).Path
$failedSuite = [System.Collections.Generic.List[string]]::new()
$completed = 0
$totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($suite in $infrastructureSuite) {
	$suitePath = Join-Path $PSScriptRoot "$suite.ps1"
	if (-not (Test-Path -LiteralPath $suitePath -PathType Leaf)) {
		$failedSuite.Add("$suite (missing)")
		Write-Output "MISSING $suite"
		continue
	}

	$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
	Write-Output "Running $suite"
	$global:LASTEXITCODE = 0
	& $pwsh -NoProfile -NonInteractive -File $suitePath
	$exitCode = $LASTEXITCODE
	$stopwatch.Stop()
	$completed++
	$seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
	if ($exitCode -ne 0) {
		$failedSuite.Add("$suite (exit $exitCode)")
		Write-Output "FAILED $suite after ${seconds}s"
	}
	else {
		Write-Output "PASSED $suite in ${seconds}s"
	}
}
$totalStopwatch.Stop()

# A suite that was not executed must not report success. Missing files already
# fail above; this count catches a future edit that skips a suite another way.
if ($completed -ne $infrastructureSuite.Count) {
	throw "Infrastructure regression coverage is incomplete: ran $completed of $($infrastructureSuite.Count) suite(s)."
}
if ($failedSuite.Count -gt 0) {
	throw "Infrastructure regression suite(s) failed: $($failedSuite -join ', ')."
}

Write-Output "Infrastructure regression checks passed: $($infrastructureSuite.Count) suites in $([math]::Round($totalStopwatch.Elapsed.TotalSeconds, 1))s."
