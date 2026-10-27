[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
Import-Module PSScriptAnalyzer -ErrorAction Stop

$source = Join-Path $PSScriptRoot '../d365bap.tools/tests'
$root = Join-Path ([IO.Path]::GetTempPath()) ('pester-runners-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $root 'd365bap.tools'
$tests = Join-Path $project 'tests'
$results = Join-Path $root 'TestResults'
$pwsh = (Get-Process -Id $PID).Path

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Reset-Fixture {
	foreach ($directory in @($tests, $results, (Join-Path $project 'functions'), (Join-Path $project 'internal'))) {
		if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
	}
	foreach ($directory in @($tests, (Join-Path $tests 'general'), (Join-Path $tests 'functions'), (Join-Path $project 'functions'), (Join-Path $project 'internal/functions'))) {
		$null = New-Item -ItemType Directory -Path $directory -Force
	}
	Copy-Item -LiteralPath (Join-Path $source 'pester.ps1'), (Join-Path $source 'pester-PSScriptAnalyzer.ps1') -Destination $tests
}

function Invoke-Runner([string] $Name, [hashtable] $Parameters) {
	$inputFile = Join-Path $root 'invocation.xml'
	@{ Runner = (Join-Path $tests $Name); Parameters = $Parameters } | Export-Clixml -LiteralPath $inputFile
	$output = @(& $pwsh -NoProfile -NonInteractive -File (Join-Path $root 'driver.ps1') $inputFile 2>&1 | ForEach-Object { "$_" }) -join "`n"
	return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Add-TestFile([string] $Path, [string] $Name) {
	Set-Content -LiteralPath $Path -Value "Describe '$Name' { It 'passes' { 1 | Should -Be 1 } }" -Encoding utf8
}

function Assert-Success($Run, [string] $Context) {
	Assert-True ($Run.ExitCode -eq 0) "$Context failed: $($Run.Output)"
}

function Assert-DiscoveryFailure($Run, [string] $Context) {
	Assert-True ($Run.ExitCode -ne 0) "$Context unexpectedly succeeded: $($Run.Output)"
	Assert-ReportedTests @()
}

function Assert-ReportedTests([string[]] $Expected) {
	$cases = @(foreach ($file in (Get-ChildItem -LiteralPath $results -Filter '*.xml')) {
			$report = [xml](Get-Content -LiteralPath $file.FullName -Raw)
			$report.SelectNodes('//test-case')
		})
	$actual = @($cases | ForEach-Object { $_.name } | Sort-Object)
	$expectedNames = @($Expected | ForEach-Object { "$_.passes" } | Sort-Object)
	Assert-True (($actual -join ',') -ceq ($expectedNames -join ',')) "Expected reported tests: $expectedNames. Actual: $actual."
	Assert-True (@($cases | Where-Object { $_.result -ne 'Success' }).Count -eq 0) 'Every selected test must pass.'
}

try {
	$null = New-Item -ItemType Directory -Path $project -Force
	Set-Content -LiteralPath (Join-Path $project 'd365bap.tools.psm1') -Value 'function Write-PSFMessage { param($Level, $Message) Write-Host $Message }; Export-ModuleMember -Function Write-PSFMessage' -Encoding utf8
	New-ModuleManifest -Path (Join-Path $project 'd365bap.tools.psd1') -RootModule 'd365bap.tools.psm1' -ModuleVersion '1.0.0' -FunctionsToExport 'Write-PSFMessage'
	Set-Content -LiteralPath (Join-Path $root 'driver.ps1') -Encoding utf8 -Value @'
param($InputFile)
$ErrorActionPreference = 'Stop'
function Write-PSFMessage { param($Level, $Message) Write-Host $Message }
try {
    $invocation = Import-Clixml -LiteralPath $InputFile
    $parameters = $invocation.Parameters
    & $invocation.Runner @parameters
    exit 0
} catch {
    Write-Host ($_ | Out-String)
    exit 1
}
'@

	foreach ($count in @(0, 1, 20, 21)) {
		Reset-Fixture
		for ($i = 1; $i -le $count; $i++) {
			$id = 'Case{0:D2}' -f $i
			Add-TestFile (Join-Path $tests "functions/$id.Tests.ps1") $id
		}
		$run = Invoke-Runner 'pester.ps1' @{ TestGeneral = $false; TestFunctions = $true }
		Assert-Success $run "$count selected function tests"
		Assert-ReportedTests @(for ($i = 1; $i -le $count; $i++) { 'Case{0:D2}' -f $i })
		Write-Host "PASS: all $count selected function tests reported exactly once"
	}

	Reset-Fixture
	$nested = New-Item -ItemType Directory -Path (Join-Path $tests 'functions/nested')
	Add-TestFile (Join-Path $tests 'functions/Keep.Tests.ps1') 'KeepFunction'
	Add-TestFile (Join-Path $nested 'KeepNested.Tests.ps1') 'KeepNested'
	Add-TestFile (Join-Path $tests 'functions/KeepExcluded.Tests.ps1') 'ExcludedFunction'
	Add-TestFile (Join-Path $tests 'functions/Other.Tests.ps1') 'OtherFunction'
	Add-TestFile (Join-Path $tests 'general/Keep.Tests.ps1') 'KeepGeneral'
	Add-TestFile (Join-Path $tests 'general/KeepExcluded.Tests.ps1') 'ExcludedGeneral'
	Add-TestFile (Join-Path $tests 'general/Other.Tests.ps1') 'OtherGeneral'
	$run = Invoke-Runner 'pester.ps1' @{ Include = 'Keep*'; Exclude = '*Excluded*' }
	Assert-Success $run 'Include/exclude filters'
	Assert-ReportedTests @('KeepFunction', 'KeepNested', 'KeepGeneral')
	Write-Host 'PASS: include/exclude filters and recursive discovery'

	foreach ($kind in @('general', 'functions')) {
		Reset-Fixture
		Set-Content -LiteralPath (Join-Path $tests "$kind/Broken.Tests.ps1") -Value "throw 'fixture discovery failure'" -Encoding utf8
		$run = Invoke-Runner 'pester.ps1' @{ TestGeneral = ($kind -eq 'general'); TestFunctions = ($kind -eq 'functions') }
		Assert-DiscoveryFailure $run "$kind discovery failure"
		Assert-True ($run.Output -match 'fixture discovery failure') "$kind discovery diagnostic missing: $($run.Output)"
		Write-Host "PASS: $kind discovery failure with zero failed tests"
	}

	foreach ($kind in @('general', 'functions')) {
		Reset-Fixture
		Set-Content -LiteralPath (Join-Path $tests "$kind/Broken.Tests.ps1") -Value "Describe 'Broken' { BeforeAll { throw 'fixture setup failure' }; It 'never runs' { 1 | Should -Be 1 } }" -Encoding utf8
		$run = Invoke-Runner 'pester.ps1' @{ TestGeneral = ($kind -eq 'general'); TestFunctions = ($kind -eq 'functions') }
		Assert-True ($run.ExitCode -ne 0) "$kind setup failure unexpectedly succeeded: $($run.Output)"
		Assert-True ($run.Output -match 'fixture setup failure') "$kind setup diagnostic missing: $($run.Output)"
		Write-Host "PASS: $kind setup failure and diagnostic"
	}

	Reset-Fixture
	Set-Content -LiteralPath (Join-Path $tests 'functions/Empty.Tests.ps1') -Value '# No tests' -Encoding utf8
	$run = Invoke-Runner 'pester.ps1' @{ TestGeneral = $false; TestFunctions = $true }
	Assert-Success $run 'Empty Pester container'
	Assert-ReportedTests @()
	Write-Host 'PASS: empty Pester container'

	foreach ($kind in @('public', 'internal')) {
		Reset-Fixture
		Set-Content -LiteralPath (Join-Path $tests 'general/PSScriptAnalyzer.Tests.ps1') -Value "throw 'analyzer fixture discovery failure'" -Encoding utf8
		$run = Invoke-Runner 'pester-PSScriptAnalyzer.ps1' @{ TestPublic = ($kind -eq 'public'); TestInternal = ($kind -eq 'internal') }
		Assert-DiscoveryFailure $run "Analyzer $kind discovery failure"
		Assert-True ($run.Output -match 'analyzer fixture discovery failure') "Analyzer $kind discovery diagnostic missing: $($run.Output)"
		Write-Host "PASS: analyzer $kind discovery failure with zero failed tests"
	}

	Reset-Fixture
	Copy-Item -LiteralPath (Join-Path $source 'general/PSScriptAnalyzer.Tests.ps1') -Destination (Join-Path $tests 'general')
	$run = Invoke-Runner 'pester-PSScriptAnalyzer.ps1' @{ TestPublic = $true; TestInternal = $true }
	if ($run.ExitCode -eq 0) {
		Assert-True ($run.Output -match 'All .*0.* tests executed') "Empty analyzer directories did not report zero tests: $($run.Output)"
	}
 else {
		Assert-DiscoveryFailure $run 'Analyzer with no source files'
	}
	Write-Host 'PASS: empty analyzer directories honor the Pester result'
	$badPath = Join-Path $project 'functions/ManyFindings.ps1'
	Set-Content -LiteralPath $badPath -Value (1..12 | ForEach-Object { "Write-Host 'finding $_'" }) -Encoding utf8
	Set-Content -LiteralPath (Join-Path $project 'internal/functions/Clean.ps1') -Value "Write-Output 'clean'" -Encoding utf8
	$expected = @(Invoke-ScriptAnalyzer -Path $badPath -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess | Where-Object RuleName -In @(Get-ScriptAnalyzerRule | ForEach-Object RuleName))
	Assert-True ($expected.Count -gt 10) "Expected more than 10 actual analyzer findings, got $($expected.Count)."
	$run = Invoke-Runner 'pester-PSScriptAnalyzer.ps1' @{ TestPublic = $true; TestInternal = $false }
	Assert-True ($run.ExitCode -ne 0) "Analyzer findings unexpectedly passed: $($run.Output)"
	foreach ($finding in $expected) {
		$linePattern = '(?m)^\s*' + [regex]::Escape($finding.RuleName) + '\s+\S+\s+\S+\s+' + $finding.Line + '\s+'
		Assert-True ($run.Output -match $linePattern) "Wrapper omitted analyzer finding $($finding.RuleName) line $($finding.Line): $($run.Output)"
	}
	Write-Host "PASS: all $($expected.Count) analyzer findings appear in wrapper diagnostics"

	$run = Invoke-Runner 'pester-PSScriptAnalyzer.ps1' @{ TestPublic = $true; TestInternal = $true }
	Assert-True ($run.ExitCode -ne 0) "Combined analyzer findings unexpectedly passed: $($run.Output)"
	foreach ($finding in $expected) {
		$linePattern = '(?m)^\s*' + [regex]::Escape($finding.RuleName) + '\s+\S+\s+\S+\s+' + $finding.Line + '\s+'
		Assert-True ($run.Output -match $linePattern) "Combined public/internal run omitted public analyzer finding $($finding.RuleName) line $($finding.Line): $($run.Output)"
	}
	Write-Host "PASS: combined analyzer run preserves all $($expected.Count) public findings"
	Write-Host 'Pester runner regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
