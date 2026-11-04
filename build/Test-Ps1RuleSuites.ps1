<#
.SYNOPSIS
	Runs every PowerShell lint rule regression suite.

.DESCRIPTION
	Discovers Test-Ps1*Rule.ps1 suites under build and runs each in a fresh pwsh
	process in parallel. Discovery is the inventory; a failing suite fails the run.

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

$suite = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test-Ps1*Rule.ps1' -File |
	Sort-Object Name |
	ForEach-Object Name)
if ($suite.Count -eq 0) {
	throw "No rule suites discovered under $PSScriptRoot (expected Test-Ps1*Rule.ps1)."
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
Write-Output "Running $($suite.Count) rule suites with ThrottleLimit=$ThrottleLimit"

try {
	$jobResult = $suite | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
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

Write-Output "Rule suite regression checks passed: $($suite.Count) suites in $([math]::Round($totalStopwatch.Elapsed.TotalSeconds, 1))s (ThrottleLimit=$ThrottleLimit)."
