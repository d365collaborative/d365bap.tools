[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
Import-Module PSScriptAnalyzer -ErrorAction Stop

$entry = Join-Path $PSScriptRoot 'ps1-lint/internal/Invoke-Ps1Analysis.ps1'
. $entry

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-analyzer-' + [guid]::NewGuid().ToString('N'))
$moduleRoot = Join-Path $root 'd365bap.tools'
$functionRoot = Join-Path $moduleRoot 'functions'
$testFile = Join-Path $moduleRoot 'tests/general/PSScriptAnalyzer.Tests.ps1'

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

# The registry is the single source for rule loading and dispatch.
$diagnosticFile = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal') -Filter 'Get-Ps1*Diagnostic.ps1' -File |
	ForEach-Object Name |
	Sort-Object)
$diagnosticRule = @(Get-Ps1DiagnosticRule)
Assert-True (($diagnosticFile -join ',') -ceq ((@($diagnosticRule.Script) | Sort-Object) -join ',')) 'Every diagnostic file must be registered exactly once.'
Assert-True (@($diagnosticRule | Where-Object { $null -eq (Get-Command -Name $_.Id -ErrorAction Ignore) }).Count -eq 0) 'Every registered rule must define its function.'
Write-Host "PASS: $($diagnosticRule.Count) diagnostic rules registered once."

function New-FixtureFile([string] $Path, [string] $Content) {
	$parent = Split-Path -Parent $Path
	if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
	Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
}

function Invoke-FixtureTest([string] $CommandPath) {
	$global:__pester_data = @{}
	$config = [PesterConfiguration]::Default
	$config.Run.Container = New-PesterContainer -Path $testFile -Data @{ CommandPath = $CommandPath }
	$config.Run.PassThru = $true
	$config.Output.Verbosity = 'None'
	Invoke-Pester -Configuration $config
}

try {
	$null = New-Item -ItemType Directory -Path $functionRoot, (Join-Path $root 'build') -Force
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint') -Destination (Join-Path $root 'build') -Recurse
	New-FixtureFile $testFile (Get-Content -LiteralPath (Join-Path $PSScriptRoot '../d365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1') -Raw)

	$analyzer = New-Ps1Analyzer

	# A clean module function must pass.
	$cleanPath = Join-Path $functionRoot 'Get-CleanFixture.ps1'
	New-FixtureFile $cleanPath @'
<#
	.SYNOPSIS
		Returns a clean fixture.

	.DESCRIPTION
		Writes a fixed string so the analyzer has a clean baseline.

	.EXAMPLE
		PS C:\> Get-CleanFixture

		Writes the fixed string.
#>
function Get-CleanFixture {
	[CmdletBinding()]
	[OutputType([string])]
	param()

	Write-Output 'clean'
}
'@
	$result = Invoke-Ps1Analysis -Path $cleanPath -Analyzer $analyzer
	Assert-True ($result.Diagnostics.Count -eq 0) 'A clean module function must not report diagnostics.'
	Assert-True (-not $result.Failed) 'A clean module function must not fail.'

	# A built-in warning is fatal for module functions, matching the full scan.
	$warningPath = Join-Path $functionRoot 'Get-WarningFixture.ps1'
	New-FixtureFile $warningPath @'
function Get-WarningFixture {
	[CmdletBinding()]
	param()

	Write-Host 'warning'
}
'@
	$result = Invoke-Ps1Analysis -Path $warningPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidUsingWriteHost').Count -eq 1) 'A module warning must be reported.'
	Assert-True ($result.Failed) 'A module warning must fail the shared policy.'

	# Custom rules are part of the changed-file policy and fail with their own rule name.
	$customPath = Join-Path $functionRoot 'Get-CustomFixture.ps1'
	New-FixtureFile $customPath @'
function Get-CustomFixture {
	[CmdletBinding()]
	param()

	return 1
}
'@
	$result = Invoke-Ps1Analysis -Path $customPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidReturnValue').Count -eq 1) 'A custom rule diagnostic must be reported.'
	Assert-True ($result.Failed) 'A custom rule diagnostic must fail the changed-file policy.'

	# A full scan skips custom rules so existing convention debt does not fail it.
	$result = Invoke-Ps1Analysis -Path $customPath -Analyzer $analyzer -SkipCustomRules
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidReturnValue').Count -eq 0) 'A full scan must not run custom rules.'
	Assert-True (-not $result.Failed) 'A full scan must not fail on custom rule debt.'

	# Build scripts keep the historical error-only gate.
	$buildPath = Join-Path $root 'build/Get-BuildFixture.ps1'
	New-FixtureFile $buildPath @'
function Get-BuildFixture {
	Write-Host 'warning'
}
'@
	$result = Invoke-Ps1Analysis -Path $buildPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidUsingWriteHost').Count -eq 1) 'A build warning must still be reported.'
	Assert-True (-not $result.Failed) 'A build warning must not fail the historical error-only gate.'

	# High-signal warnings fail build scripts even though ordinary warnings do not.
	$emptyCatchPath = Join-Path $root 'build/Get-EmptyCatchFixture.ps1'
	New-FixtureFile $emptyCatchPath @'
function Get-EmptyCatchFixture {
	try {
		Get-Thing
	}
	catch { }
}
'@
	$result = Invoke-Ps1Analysis -Path $emptyCatchPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidUsingEmptyCatchBlock').Count -eq 1) 'An empty catch must be reported.'
	Assert-True ($result.Failed) 'An empty catch in build code must fail the high-signal gate.'

	# Tepp files stay outside the high-signal gate.
	$teppPath = Join-Path $moduleRoot 'internal/tepp/Get-TeppFixture.ps1'
	New-FixtureFile $teppPath @'
try {
	Get-Thing
}
catch { }
'@
	$result = Invoke-Ps1Analysis -Path $teppPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidUsingEmptyCatchBlock').Count -eq 1) 'A tepp empty catch must still be reported.'
	Assert-True (-not $result.Failed) 'A tepp file must stay outside the high-signal gate.'

	# Module functions use the repository ShouldProcess rule instead of the built-in check.
	$shouldPath = Join-Path $functionRoot 'Set-ShouldFixture.ps1'
	New-FixtureFile $shouldPath @'
function Set-ShouldFixture {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param()

	Write-Output 'changed'
}
'@
	$result = Invoke-Ps1Analysis -Path $shouldPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSUseShouldProcessConvention').Count -eq 1) 'The repository ShouldProcess rule must report a declaration without a call.'
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSShouldProcess').Count -eq 0) 'The built-in ShouldProcess check must be filtered for module functions.'
	Assert-True ($result.Failed) 'A ShouldProcess convention violation must fail.'

	# Build scripts keep the built-in ShouldProcess check.
	$buildShouldPath = Join-Path $root 'build/Set-ShouldFixture.ps1'
	New-FixtureFile $buildShouldPath @'
function Set-ShouldFixture {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param()

	Write-Output 'changed'
}
'@
	$result = Invoke-Ps1Analysis -Path $buildShouldPath -Analyzer $analyzer
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSShouldProcess').Count -eq 1) 'The built-in ShouldProcess check must remain for build scripts.'
	Assert-True (@($result.Diagnostics | Where-Object RuleName -eq 'PSUseShouldProcessConvention').Count -eq 0) 'The repository ShouldProcess rule must stay out of build scripts.'
	Assert-True (-not $result.Failed) 'A build ShouldProcess warning must remain non-fatal.'

	# A parse error is fatal and short-circuits the rest of the analysis.
	$syntaxPath = Join-Path $functionRoot 'Get-SyntaxFixture.ps1'
	New-FixtureFile $syntaxPath 'function Get-SyntaxFixture {'
	$result = Invoke-Ps1Analysis -Path $syntaxPath -Analyzer $analyzer
	Assert-True ($result.Diagnostics.Count -eq 1) 'A parse error must be the only diagnostic.'
	Assert-True ($result.Diagnostics[0].RuleName -eq 'PSParseError') 'A parse error must use the PSParseError rule name.'
	Assert-True ($result.Failed) 'A parse error must always fail.'

	# The Pester entry point must fail clean, warning, and syntax fixtures correctly.
	$pesterClean = Join-Path $root 'pester-clean/d365bap.tools/functions'
	New-FixtureFile (Join-Path $pesterClean 'Get-PesterClean.ps1') "Write-Output 'clean'"
	$result = Invoke-FixtureTest $pesterClean
	Assert-True ($result.Result -eq 'Passed') 'A clean Pester fixture must pass.'

	$pesterWarning = Join-Path $root 'pester-warning/d365bap.tools/functions'
	New-FixtureFile (Join-Path $pesterWarning 'Get-PesterWarning.ps1') @'
function Get-PesterWarning {
	[CmdletBinding()]
	param()

	Write-Host 'warning'
}
'@
	$result = Invoke-FixtureTest $pesterWarning
	Assert-True ($result.Result -eq 'Failed') 'A warning Pester fixture must fail.'

	$pesterSyntax = Join-Path $root 'pester-syntax/d365bap.tools/functions'
	New-FixtureFile (Join-Path $pesterSyntax 'Get-PesterSyntax.ps1') 'function Get-PesterSyntax {'
	$result = Invoke-FixtureTest $pesterSyntax
	Assert-True ($result.Result -eq 'Failed') 'A syntax Pester fixture must fail.'
	Assert-True ((($result.Failed | ForEach-Object { $_.ErrorRecord | Out-String }) -join "`n") -match 'PSParseError|Expected \$false') 'A syntax Pester failure must identify the parse policy.'

	Write-Host 'Shared analyzer regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
