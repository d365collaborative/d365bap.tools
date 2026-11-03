<#
.SYNOPSIS
	Runs every PowerShell lint rule regression suite.

.DESCRIPTION
	Discovers rule suites under build, checks the registry, and runs each suite
	in a fresh pwsh process in parallel. A missing, unregistered, or failing
	suite fails the run.

.PARAMETER ThrottleLimit
	Maximum concurrent suite processes.

	Default: min(4, processor count)
#>
[CmdletBinding()]
param(
	[ValidateRange(1, 32)]
	[int] $ThrottleLimit = 0
)

$ErrorActionPreference = 'Stop'

# Keep this list in sync with build/Test-Ps1*Rule.ps1. A missing entry fails
# the run instead of dropping the suite from CI.
$expectedSuite = @(
	'Test-Ps1AccessTokenRule.ps1'
	'Test-Ps1AddMemberRule.ps1'
	'Test-Ps1AliasRule.ps1'
	'Test-Ps1CentralApiVersionRule.ps1'
	'Test-Ps1CommentRule.ps1'
	'Test-Ps1ComplexArrayElementRule.ps1'
	'Test-Ps1ParameterPresenceRule.ps1'
	'Test-Ps1DirectStringCheckRule.ps1'
	'Test-Ps1EmptyAttributeRule.ps1'
	'Test-Ps1EmptyLineAfterContinuationRule.ps1'
	'Test-Ps1EnvironmentLookupRule.ps1'
	'Test-Ps1FormattedUrlRule.ps1'
	'Test-Ps1FunctionInterruptRule.ps1'
	'Test-Ps1HeadersVariableRule.ps1'
	'Test-Ps1LoopAppendRule.ps1'
	'Test-Ps1MandatoryRule.ps1'
	'Test-Ps1ModuleSplattingRule.ps1'
	'Test-Ps1MultilineIfConditionRule.ps1'
	'Test-Ps1MultilineIfExpressionRule.ps1'
	'Test-Ps1NullComparisonRule.ps1'
	'Test-Ps1ObjectArrayCastRule.ps1'
	'Test-Ps1OneParameterPerLineRule.ps1'
	'Test-Ps1OrderedPSCustomObjectRule.ps1'
	'Test-Ps1OutNullRule.ps1'
	'Test-Ps1OutputTypeRule.ps1'
	'Test-Ps1ParameterArgumentRule.ps1'
	'Test-Ps1ParameterLayoutRule.ps1'
	'Test-Ps1ParameterPositionRule.ps1'
	'Test-Ps1PipelineContinuationRule.ps1'
	'Test-Ps1ReturnAfterStopRule.ps1'
	'Test-Ps1ReturnValueRule.ps1'
	'Test-Ps1SelectObjectPropertyRule.ps1'
	'Test-Ps1ShouldProcessRule.ps1'
	'Test-Ps1StandardExcelExportRule.ps1'
	'Test-Ps1StandardOutputRule.ps1'
	'Test-Ps1TernaryInObjectInitializationRule.ps1'
	'Test-Ps1ValidationAttributeOnMandatoryRule.ps1'
	'Test-Ps1VariableNamingRule.ps1'
	'Test-Ps1WildcardParameterAsFilterRule.ps1'
	'Test-Ps1WildcardRule.ps1'
)

$discovered = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test-Ps1*Rule.ps1' -File |
	Sort-Object Name |
	ForEach-Object Name)

$missingSuite = @($expectedSuite | Where-Object { $_ -notin $discovered })
if ($missingSuite.Count -gt 0) {
	throw "Missing rule suite(s): $($missingSuite -join ', '). Restore the file or remove it from the registry."
}

$unregisteredSuite = @($discovered | Where-Object { $_ -notin $expectedSuite })
if ($unregisteredSuite.Count -gt 0) {
	throw "Unregistered rule suite(s): $($unregisteredSuite -join ', '). Add them to `$expectedSuite in $PSCommandPath."
}

if ($ThrottleLimit -le 0) {
	# windows-latest public runners expose 4 vCPUs; cap so local high-core boxes
	# do not spawn dozens of pwsh processes for tiny fixture scripts.
	$ThrottleLimit = [Math]::Max(1, [Math]::Min(4, [Environment]::ProcessorCount))
}

$pwsh = (Get-Process -Id $PID).Path
$root = $PSScriptRoot
$logRoot = Join-Path ([IO.Path]::GetTempPath()) ('rule-suites-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $logRoot -Force
$totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Output "Running $($expectedSuite.Count) rule suites with ThrottleLimit=$ThrottleLimit"

try {
	$jobResult = $expectedSuite | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
		$itemSuite = $_
		$suitePath = Join-Path $using:root $itemSuite
		$stdoutPath = Join-Path $using:logRoot ($itemSuite + '.out.log')
		$stderrPath = Join-Path $using:logRoot ($itemSuite + '.err.log')
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		$process = Start-Process -FilePath $using:pwsh `
			-ArgumentList @('-NoProfile', '-NonInteractive', '-File', $suitePath) `
			-WorkingDirectory $using:root `
			-RedirectStandardOutput $stdoutPath `
			-RedirectStandardError $stderrPath `
			-Wait `
			-PassThru `
			-NoNewWindow
		$stopwatch.Stop()
		[pscustomobject]@{
			Suite    = $itemSuite
			ExitCode = $process.ExitCode
			Seconds  = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
		}
	}
}
finally {
	if (Test-Path -LiteralPath $logRoot) {
		Remove-Item -LiteralPath $logRoot -Recurse -Force -ErrorAction SilentlyContinue
	}
}

$totalStopwatch.Stop()
$failedSuite = [System.Collections.Generic.List[string]]::new()
foreach ($itemResult in @($jobResult | Where-Object { $_ -is [pscustomobject] -and $_.Suite } | Sort-Object Suite)) {
	if ($itemResult.ExitCode -ne 0) {
		$failedSuite.Add("$($itemResult.Suite) (exit $($itemResult.ExitCode))")
		Write-Output "FAILED $($itemResult.Suite) after $($itemResult.Seconds)s"
	}
	else {
		Write-Output "PASSED $($itemResult.Suite) in $($itemResult.Seconds)s"
	}
}

if ($failedSuite.Count -gt 0) {
	throw "Rule suite(s) failed: $($failedSuite -join ', ')."
}

Write-Output "Rule suite regression checks passed: $($expectedSuite.Count) suites in $([math]::Round($totalStopwatch.Elapsed.TotalSeconds, 1))s (ThrottleLimit=$ThrottleLimit)."
