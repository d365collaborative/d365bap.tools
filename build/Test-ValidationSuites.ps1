<#
.SYNOPSIS
	Runs the selected validation regression suites.

.DESCRIPTION
	Uses Get-ValidationSuitePlan as the suite inventory, verifies every
	build/Test-*.ps1 is planned, intentionally excluded, or a rule suite, then
	runs each selected suite in a fresh pwsh process.

.PARAMETER BaseSha
	Pull request base commit for suite selection.

	Default: $env:BASE_SHA

.PARAMETER HeadSha
	Pull request head commit for suite selection.

	Default: $env:HEAD_SHA

.PARAMETER ForceAll
	Run every registered suite.
#>
[CmdletBinding()]
param(
	[string] $BaseSha = $env:BASE_SHA,

	[string] $HeadSha = $env:HEAD_SHA,

	[switch] $ForceAll
)

$ErrorActionPreference = 'Stop'

# Intentional exclusions only. Suite inventory lives in Get-ValidationSuitePlan
# (SuitePattern keys). Rule suites are owned by Test-Ps1RuleSuites.ps1.
$notSuite = [ordered]@{
	'Test-Behavior.ps1'                = 'Runs in validate.yml and build-v2.yml.'
	'Test-CiLintPlan.ps1'              = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-CompiledImport.ps1'          = 'Runs in validate.yml and build-v2.yml.'
	'Test-CompiledImportFormats.ps1'   = 'Runs in build-v2.yml.'
	'Test-GeneratedTouch.ps1'          = 'Runs in validate.yml.'
	'Test-PowerPlatformSdk.ps1'        = 'Run manually; not part of CI.'
	'Test-PrekInstall.ps1'             = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-PRValidationPlan.ps1'        = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-Ps1FormatXml.ps1'            = 'Runs in the validate.yml infrastructure-tests job.'
	'Test-Ps1AnalysisCache.ps1'        = 'Runs in the validate.yml infrastructure-tests job.'
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

$planPath = Join-Path ([IO.Path]::GetTempPath()) ('validation-suite-plan-' + [guid]::NewGuid().ToString('N') + '.json')
$planArgs = @{
	RepositoryPath = (Split-Path -Parent $PSScriptRoot)
	OutputPath     = $planPath
}
if ($ForceAll) { $planArgs.ForceAll = $true }
if ($BaseSha) { $planArgs.BaseSha = $BaseSha }
if ($HeadSha) { $planArgs.HeadSha = $HeadSha }

try {
	$null = & (Join-Path $PSScriptRoot 'Get-ValidationSuitePlan.ps1') @planArgs
	$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
}
finally {
	if (Test-Path -LiteralPath $planPath) { Remove-Item -LiteralPath $planPath -Force }
}

$expectedSuite = @($plan.AllSuites)
if ($expectedSuite.Count -eq 0) {
	throw 'Get-ValidationSuitePlan returned no AllSuites inventory.'
}

$missingSuite = @($expectedSuite | Where-Object { $_ -notin $discovered })
if ($missingSuite.Count -gt 0) {
	throw "Missing validation suite(s): $($missingSuite -join ', '). Restore the file or remove it from SuitePattern in Get-ValidationSuitePlan.ps1."
}

$unregisteredSuite = @($discovered | Where-Object {
		$_ -notin $expectedSuite -and
		-not $notSuite.Contains($_) -and
		$_ -notlike $ruleSuitePattern
	})
if ($unregisteredSuite.Count -gt 0) {
	throw "Unregistered validation suite(s): $($unregisteredSuite -join ', '). Add them to SuitePattern in Get-ValidationSuitePlan.ps1 or list them in `$notSuite with the workflow that runs them."
}

$selectedSuite = @($plan.Suites)
foreach ($itemSuite in $selectedSuite) {
	if ($itemSuite -notin $expectedSuite) {
		throw "Validation suite plan selected unknown suite: $itemSuite"
	}
}

if ($selectedSuite.Count -eq 0) {
	Write-Output 'Validation suite regression checks passed: 0 suites selected for this diff.'
	return
}

$pwsh = (Get-Process -Id $PID).Path
$rootTemp = Join-Path ([IO.Path]::GetTempPath()) ('validation-suites-' + [guid]::NewGuid().ToString('N'))
$failedSuite = [System.Collections.Generic.List[string]]::new()
$result = [System.Collections.Generic.List[object]]::new()
$totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$null = New-Item -ItemType Directory -Path $rootTemp -Force

try {
	foreach ($itemSuite in $selectedSuite) {
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

Write-Output "Validation suite regression checks passed: $($selectedSuite.Count) of $($expectedSuite.Count) suite(s) in $([math]::Round($totalStopwatch.Elapsed.TotalSeconds, 1))s."
