<#
.SYNOPSIS
    Runs every validation regression suite.

.DESCRIPTION
    Discovers the validation suites under build, checks them against the
    explicit registry, and runs each suite in a fresh pwsh process with its own
    working directory. A missing, unregistered, or failing suite fails the run.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Keep this list in sync with build/Test-*.ps1. A missing entry fails the run
# instead of dropping the suite from CI. The Node test is not listed because it
# runs under node --test in the workflow.
$expectedSuite = @(
	'Test-PreloadExitCode.ps1'
	'Test-ModulePublication.ps1'
	'Test-Ps1ExampleHelp.ps1'
	'Test-Ps1RuleSuites.ps1'
	'Test-RequiredModules.ps1'
	'Test-PSScriptAnalyzerConsolidation.ps1'
	'Test-PesterRunners.ps1'
)

# build/Test-*.ps1 scripts that this runner must not execute. Rule suites are
# owned by Test-Ps1RuleSuites.ps1. Every other script runs in another workflow
# or is sourced by a test, so a new build/Test-*.ps1 fails here until it is
# registered above or listed below.
$notSuite = [ordered]@{
	'Test-Behavior.ps1'                = 'Runs in validate.yml and build-v2.yml.'
	'Test-CiLintPlan.ps1'              = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-CompiledImport.ps1'          = 'Runs in validate.yml and build-v2.yml.'
	'Test-CompiledImportFormats.ps1'   = 'Runs in build-v2.yml.'
	'Test-GeneratedTouch.ps1'          = 'Runs in validate.yml.'
	'Test-PowerPlatformSdk.ps1'        = 'Run manually; not part of CI.'
	'Test-PRValidationPlan.ps1'        = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-Ps1FormatXml.ps1'            = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-Ps1LintBatch.ps1'            = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-Ps1LintCorrectness.ps1'      = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-Ps1LintScope.ps1'            = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-SelectedStrings.ps1'         = 'Sourced by Invoke-SelectiveValidation.ps1 and its tests.'
	'Test-SelectedStringsHandling.ps1' = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-SelectiveValidation.ps1'     = 'Runs in the validate.yml infrastructure-tests job.'
}
$ruleSuitePattern = 'Test-Ps1*Rule.ps1'

$discovered = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test-*.ps1' -File |
	Where-Object FullName -ne $PSCommandPath |
	Sort-Object Name |
	ForEach-Object Name)

$missingSuite = @($expectedSuite | Where-Object { $_ -notin $discovered })
if ($missingSuite.Count -gt 0) {
	throw "Missing validation suite(s): $($missingSuite -join ', '). Restore the file or remove it from the registry in $PSCommandPath."
}

$unregisteredSuite = @($discovered | Where-Object {
		$_ -notin $expectedSuite -and
		-not $notSuite.Contains($_) -and
		$_ -notlike $ruleSuitePattern
	})
if ($unregisteredSuite.Count -gt 0) {
	throw "Unregistered validation suite(s): $($unregisteredSuite -join ', '). Add them to `$expectedSuite in $PSCommandPath or list them in `$notSuite with the workflow that runs them."
}

$pwsh = (Get-Process -Id $PID).Path
$rootTemp = Join-Path ([IO.Path]::GetTempPath()) ('validation-suites-' + [guid]::NewGuid().ToString('N'))
$failedSuite = [System.Collections.Generic.List[string]]::new()
$result = [System.Collections.Generic.List[object]]::new()
$totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$null = New-Item -ItemType Directory -Path $rootTemp -Force

try {
	foreach ($itemSuite in $expectedSuite) {
		# A fresh process and working directory per suite: no suite can mutate
		# another suite's variables, environment, or relative files.
		$suitePath = Join-Path $PSScriptRoot $itemSuite
		$workingDirectory = Join-Path $rootTemp ([IO.Path]::GetFileNameWithoutExtension($itemSuite))
		$null = New-Item -ItemType Directory -Path $workingDirectory -Force
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		Write-Output "Running $itemSuite"
		Push-Location -LiteralPath $workingDirectory
		try {
			$global:LASTEXITCODE = 0
			& $pwsh -NoProfile -NonInteractive -File $suitePath
			$exitCode = $LASTEXITCODE
		}
		finally {
			Pop-Location
		}
		$stopwatch.Stop()
		$seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
		if ($exitCode -ne 0) {
			$failedSuite.Add("$itemSuite (exit $exitCode)")
			Write-Output "FAILED $itemSuite after ${seconds}s"
		}
		else {
			Write-Output "PASSED $itemSuite in ${seconds}s"
		}
		$result.Add([pscustomobject]@{ Suite = $itemSuite; ExitCode = $exitCode; Seconds = $seconds })
	}
}
finally {
	if (Test-Path -LiteralPath $rootTemp) { Remove-Item -LiteralPath $rootTemp -Recurse -Force }
}
$totalStopwatch.Stop()

$result | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
if ($failedSuite.Count -gt 0) {
	throw "Validation suite(s) failed: $($failedSuite -join ', ')."
}

Write-Output "Validation suite regression checks passed: $($expectedSuite.Count) suites in $([math]::Round($totalStopwatch.Elapsed.TotalSeconds, 1))s."
