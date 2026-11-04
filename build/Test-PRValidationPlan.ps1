[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('pr-plan-tests-' + [guid]::NewGuid().ToString('N'))
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$pwsh = (Get-Process -Id $PID).Path
$detector = Join-Path $PSScriptRoot 'Get-PRValidationPlan.ps1'

function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Git([string[]] $Arguments) {
	$colOutput = @(& $gitExe -C $root @Arguments 2>&1)
	if ($LASTEXITCODE -ne 0) { throw "git $Arguments failed: $colOutput" }
	($colOutput -join "`n")
}
function Write-Fixture([string] $Path, [string] $Content) {
	$file = Join-Path $root $Path
	$null = New-Item -ItemType Directory -Path (Split-Path $file) -Force
	Set-Content -LiteralPath $file -Value $Content -Encoding utf8
}
function Commit([string] $Message) {
	$null = Git @('add', '-A')
	$null = Git @('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', $Message)
	(Git @('rev-parse', 'HEAD')).Trim()
}
function Get-Plan([string] $Base, [string] $Head) {
	$out = Join-Path ([IO.Path]::GetTempPath()) ('pr-plan-' + [guid]::NewGuid().ToString('N') + '.json')
	try {
		& $detector -BaseSha $Base -HeadSha $Head -OutputPath $out -RepositoryPath $root
		Get-Content -Raw -LiteralPath $out | ConvertFrom-Json
	}
	finally { Remove-Item -LiteralPath $out -Force -ErrorAction Ignore }
}
function Assert-BaseScopeCompatibility($Plan, [string] $Label) {
	# The base-branch workflow (9042c76) reads Mode and rejects anything else.
	$pair = "$($Plan.Mode)|$($Plan.InfrastructureChange.ToString().ToLowerInvariant())"
	if ($pair -notin @('docs|false', 'selective|false', 'full|false', 'full|true')) {
		throw "$Label`: the base workflow rejects the compatibility pair '$pair' (scope $($Plan.Scope))."
	}
}
function Assert-Scope($Plan, [hashtable] $Expected, [string] $Label, [switch] $Gate) {
	foreach ($itemKey in $Expected.Keys) {
		if ($Plan.$itemKey -ne $Expected[$itemKey]) {
			throw "$Label`: expected $itemKey $($Expected[$itemKey]), got $($Plan.$itemKey) (scope $($Plan.Scope))."
		}
	}
	Assert-BaseScopeCompatibility $Plan $Label
	if ($Gate) { Assert-GateMatchesPlan $Plan $Label }
}
function Assert-GeneratedRejected([string] $Base, [string] $Head) {
	$guard = Join-Path $PSScriptRoot 'Test-GeneratedTouch.ps1'
	Push-Location $root
	try {
		$output = & pwsh -NoProfile -NonInteractive -File $guard -BaseRef $Base -HeadRef $Head 2>&1 | Out-String
		Assert-True ($LASTEXITCODE -ne 0 -and $output -match 'must not change generated files') "Generated test change was accepted: $output"
	}
	finally { Pop-Location }
}
function Reset-Base { $null = Git @('reset', '--hard', $script:base) }
function Invoke-ResultGate([hashtable] $Overrides) {
	$hashDefault = [ordered]@{
		Lint                 = 'success'
		ChangeResult         = 'success'
		Scope                = 'module-tests+analyzer-scans+compiled-import'
		PlanHash             = ('A' * 64)
		SelectiveHash        = ''
		CompiledHash         = ('A' * 64)
		SelectiveScope       = ''
		CompiledScope        = 'module-tests+analyzer-scans+compiled-import'
		ModuleTests          = 'true'
		AnalyzerScans        = 'true'
		SelectiveTests       = 'false'
		CompiledImport       = 'true'
		InfrastructureChange = 'false'
		General              = 'success'
		Public               = 'success'
		Internal             = 'success'
		Selective            = 'skipped'
		Compiled             = 'success'
		InfrastructureResult = 'skipped'
	}
	foreach ($itemKey in $Overrides.Keys) { $hashDefault[$itemKey] = $Overrides[$itemKey] }
	$hashArguments = @{}
	foreach ($itemKey in $hashDefault.Keys) {
		# A null override omits the parameter, which simulates a missing job result.
		if ($null -eq $hashDefault[$itemKey]) { continue }
		$hashArguments[$itemKey] = [string] $hashDefault[$itemKey]
	}
	$output = ''
	$exitCode = 0
	# The gate is a script with its own scope: run it in-process so the many
	# combinations stay fast, and treat any throw (including parameter binding)
	# as a rejection.
	try { & (Join-Path $PSScriptRoot 'Invoke-ValidationResultGate.ps1') @hashArguments 6>$null }
	catch { $exitCode = 1; $output = $_.Exception.Message }
	[pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}
function New-GateCase([hashtable] $Base, [string] $Key, $Value) {
	$hashClone = @{}
	foreach ($itemKey in $Base.Keys) { $hashClone[$itemKey] = $Base[$itemKey] }
	$hashClone[$Key] = $Value
	$hashClone
}
function Assert-Gate([hashtable] $Overrides, [bool] $Pass, [string] $Label) {
	$result = Invoke-ResultGate $Overrides
	if ($Pass -and $result.ExitCode -ne 0) { throw "Result gate rejected $Label`: $($result.Output)" }
	if (-not $Pass -and $result.ExitCode -eq 0) { throw "Result gate accepted $Label" }
}
function Assert-GateMatchesPlan($Plan, [string] $Label) {
	$hashPlan = @{
		Scope                = $Plan.Scope
		PlanHash             = ('A' * 64)
		ModuleTests          = $Plan.ModuleTests.ToString().ToLowerInvariant()
		AnalyzerScans        = $Plan.AnalyzerScans.ToString().ToLowerInvariant()
		SelectiveTests       = $Plan.SelectiveTests.ToString().ToLowerInvariant()
		CompiledImport       = $Plan.CompiledImport.ToString().ToLowerInvariant()
		InfrastructureChange = $Plan.InfrastructureChange.ToString().ToLowerInvariant()
		SelectiveHash        = if ($Plan.SelectiveTests) { 'A' * 64 } else { '' }
		SelectiveScope       = if ($Plan.SelectiveTests) { $Plan.Scope } else { '' }
		CompiledHash         = if ($Plan.CompiledImport) { 'A' * 64 } else { '' }
		CompiledScope        = if ($Plan.CompiledImport) { $Plan.Scope } else { '' }
		General              = if ($Plan.ModuleTests) { 'success' } else { 'skipped' }
		Public               = if ($Plan.AnalyzerScans) { 'success' } else { 'skipped' }
		Internal             = if ($Plan.AnalyzerScans) { 'success' } else { 'skipped' }
		Selective            = if ($Plan.SelectiveTests) { 'success' } else { 'skipped' }
		Compiled             = if ($Plan.CompiledImport) { 'success' } else { 'skipped' }
		InfrastructureResult = if ($Plan.InfrastructureChange) { 'success' } else { 'skipped' }
	}
	Assert-Gate $hashPlan $true "$Label (the gate accepts the emitted scope)"
	foreach ($itemName in @('General', 'Public', 'Internal', 'Selective', 'Compiled', 'InfrastructureResult')) {
		$required = switch ($itemName) {
			'General' { $Plan.ModuleTests }
			'Public' { $Plan.AnalyzerScans }
			'Internal' { $Plan.AnalyzerScans }
			'Selective' { $Plan.SelectiveTests }
			'Compiled' { $Plan.CompiledImport }
			'InfrastructureResult' { $Plan.InfrastructureChange }
		}
		if (-not $required) { continue }
		Assert-Gate (New-GateCase $hashPlan $itemName 'skipped') $false "$Label with a skipped required $itemName job"
	}
}

# Scope shapes the plan can emit. Every path-class assertion below names one of
# them, so a decision that spreads to an unrelated job fails the regression.
$docsScope = @{ Mode = 'docs'; ModuleTests = $false; AnalyzerScans = $false; SelectiveTests = $false; CompiledImport = $false; InfrastructureChange = $false; Scope = 'docs' }
$compileScope = @{ Mode = 'full'; ModuleTests = $false; AnalyzerScans = $false; SelectiveTests = $false; CompiledImport = $true; InfrastructureChange = $false; Scope = 'compiled-import' }
$selectiveScope = @{ Mode = 'selective'; ModuleTests = $false; AnalyzerScans = $false; SelectiveTests = $true; CompiledImport = $true; InfrastructureChange = $false; Scope = 'selective+compiled-import' }
$moduleScope = @{ Mode = 'full'; ModuleTests = $true; AnalyzerScans = $true; SelectiveTests = $false; CompiledImport = $true; InfrastructureChange = $false; Scope = 'module-tests+analyzer-scans+compiled-import' }
$moduleTestsScope = @{ Mode = 'full'; ModuleTests = $true; AnalyzerScans = $false; SelectiveTests = $false; CompiledImport = $true; InfrastructureChange = $false; Scope = 'module-tests+compiled-import' }
$analyzerScope = @{ Mode = 'full'; ModuleTests = $false; AnalyzerScans = $true; SelectiveTests = $false; CompiledImport = $true; InfrastructureChange = $false; Scope = 'analyzer-scans+compiled-import' }
$infrastructureScope = @{ Mode = 'full'; ModuleTests = $false; AnalyzerScans = $false; SelectiveTests = $false; CompiledImport = $true; InfrastructureChange = $true; Scope = 'compiled-import+infrastructure' }
$fullScope = @{ Mode = 'full'; ModuleTests = $true; AnalyzerScans = $true; SelectiveTests = $false; CompiledImport = $true; InfrastructureChange = $true; Scope = 'module-tests+analyzer-scans+compiled-import+infrastructure' }

try {
	$null = New-Item -ItemType Directory -Path $root -Force
	$null = Git @('init', '-q')
	Write-Fixture 'README.md' 'readme'
	Write-Fixture 'docs/example.md' 'docs'
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
function Get-Example {
	1
}
'@
	Write-Fixture 'd365bap.tools/functions/Get-Sample.ps1' 'function Get-Sample { "a b" }'
	Write-Fixture 'd365bap.tools/functions/Get-Continuation.ps1' @'
function Get-Continuation {
	Get-ChildItem `
		-Path .
}
'@
	Write-Fixture 'd365bap.tools/internal/functions/Get-Shared.ps1' @'
function Get-Shared {
	1
}
'@
	Write-Fixture 'd365bap.tools/d365bap.tools.psd1' "@{ ModuleVersion = '1.0.0' }"
	Write-Fixture 'd365bap.tools/d365bap.tools.psm1' @'
function Get-Thing {
	1
}
'@
	Write-Fixture 'd365bap.tools/tests/functions/Get-Example.Tests.ps1' 'test'
	Write-Fixture 'd365bap.tools/tests/general/Manifest.Tests.ps1' "Describe 'Manifest' { It 'runs' { 1 | Should -Be 1 } }"
	Write-Fixture 'd365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1' "Describe 'Analyzer' { It 'runs' { 1 | Should -Be 1 } }"
	Write-Fixture 'd365bap.tools/tests/pester.ps1' '# general runner'
	Write-Fixture 'd365bap.tools/tests/pester-PSScriptAnalyzer.ps1' '# analyzer runner'
	Write-Fixture 'd365bap.tools/tests/behavior/Sample.Tests.ps1' "Describe 'Behavior' { It 'runs' { 1 | Should -Be 1 } }"
	Write-Fixture 'build/config.json' '{}'
	Write-Fixture 'build/Test-Behavior.ps1' 'exit 0'
	Write-Fixture 'build/Merge-FormatPs1Xml.ps1' 'function Merge-FormatPs1Xml { 1 }'
	Write-Fixture 'build/update-docs.ps1' 'function Update-Docs { 1 }'
	$base = Commit 'base'

	Write-Fixture 'docs/example.md' 'changed docs'
	$head = Commit 'docs'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $docsScope 'Docs' -Gate
	Assert-True ($plan.Mode -ceq 'docs') 'Documentation must keep the compatibility mode docs.'
	Assert-True ($plan.PublicPaths.Count -eq 0) 'Docs must not select public paths.'
	Assert-True ($plan.InfrastructurePaths.Count -eq 0) 'Docs must not select the infrastructure job.'
	Reset-Base

	foreach ($path in @('wiki/example.md', 'learning/course/chapter.md', 'd365bap.tools/readme.md', 'd365bap.tools/changelog.md')) {
		Write-Fixture $path 'documentation'
		$head = Commit 'additional documentation'
		Assert-Scope (Get-Plan $base $head) $docsScope "Recognized documentation ($path)"
		Reset-Base
	}

	# A modest public-function change runs only its targeted checks and the
	# compiled import: no module-wide suites and no full analyzer scans.
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
function Get-Example {
	2
}
'@
	Write-Fixture 'README.md' 'also changed'
	$head = Commit 'public and docs'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $selectiveScope 'Public modification' -Gate
	Assert-True ($plan.Mode -ceq 'selective') 'A public-function change must keep the compatibility mode selective.'
	Assert-True ($plan.PublicPaths.Count -eq 1 -and $plan.PublicPaths[0] -ceq 'd365bap.tools/functions/Get-Example.ps1') 'The changed source must be included.'
	Reset-Base

	# Whitespace inside a line, indentation, and blank lines keep executable
	# tokens, so formatting-only and help/layout-only changes skip compile work.
	Write-Fixture 'd365bap.tools/internal/functions/Get-Shared.ps1' @'
function Get-Shared   {

		1

}
'@
	$head = Commit 'formatting only shared code'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $docsScope 'Formatting-only shared change' -Gate
	Assert-True ($plan.Mode -ceq 'docs') 'A formatting-only change must report the compatibility mode docs.'
	Assert-True (@($plan.Reasons -match 'Formatting-only|Executable-unchanged').Count -gt 0) 'The formatting-only scope must explain itself.'

	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
function   Get-Example   {
		1
}
'@
	$head = Commit 'formatting only public function'
	Assert-Scope (Get-Plan $base $head) $docsScope 'Formatting-only public function'
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
# Changed comment
function Get-Example {
	1
}
'@
	$head = Commit 'comment change'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $docsScope 'Comment change'
	Assert-True (@($plan.Reasons -match 'Executable-unchanged').Count -gt 0) 'Comment-only edits must explain the executable-unchanged skip.'
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
function Get-Example {
	1 }
'@
	$head = Commit 'moved line break'
	Assert-Scope (Get-Plan $base $head) $docsScope 'Moved line break'
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-Continuation.ps1' @'
function Get-Continuation {
	Get-ChildItem -Path .
}
'@
	$head = Commit 'backtick layout only'
	Assert-Scope (Get-Plan $base $head) $docsScope 'Backtick layout that keeps executable tokens'
	Reset-Base

	# Real executable edits keep selective or full coverage.
	Write-Fixture 'd365bap.tools/internal/functions/Get-Shared.ps1' @'
function Get-Shared {
	2
}
'@
	$head = Commit 'shared value change'
	Assert-Scope (Get-Plan $base $head) $moduleScope 'Shared value change' -Gate
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-Sample.ps1' 'function Get-Sample { "a  b" }'
	$head = Commit 'string whitespace change'
	Assert-Scope (Get-Plan $base $head) $selectiveScope 'String literal change'
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-Continuation.ps1' ("function Get-Continuation {`n`tGet-ChildItem `` " + "`n`t`t-Path .`n}")
	Assert-True (((Get-Content -Raw -LiteralPath (Join-Path $root 'd365bap.tools/functions/Get-Continuation.ps1')) -match '(?m)`[ ]+\r?$')) 'The continuation fixture must end a line with a backtick and a space.'
	$head = Commit 'continuation whitespace change'
	Assert-Scope (Get-Plan $base $head) $selectiveScope 'Continuation whitespace change'
	Reset-Base

	# A new file has no base to compare, and tooling outside the analyzers' input
	# keeps its own scope rather than riding along with the module tests.
	Write-Fixture 'd365bap.tools/functions/Get-New.ps1' 'function Get-New { 1 }'
	$head = Commit 'new public function'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $selectiveScope 'New public function'
	Assert-True ($plan.PublicPaths[0] -ceq 'd365bap.tools/functions/Get-New.ps1') 'New functions without generated tests must be selected.'
	Reset-Base

	Write-Fixture 'build/Test-Behavior.ps1' @'
exit   0
'@
	$head = Commit 'infrastructure formatting only'
	Assert-Scope (Get-Plan $base $head) $infrastructureScope 'Infrastructure formatting change'
	Reset-Base

	# Module test harness decisions: the analyzer harness is the only test input
	# the full scans read, and the general runner is the only one the module
	# suites read.
	foreach ($case in @(
			@{ Path = 'd365bap.tools/tests/general/Manifest.Tests.ps1'; Scope = $moduleTestsScope }
			@{ Path = 'd365bap.tools/tests/pester.ps1'; Scope = $moduleTestsScope }
			@{ Path = 'd365bap.tools/tests/functions/Get-Example.Tests.ps1'; Scope = $moduleTestsScope }
			@{ Path = 'd365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1'; Scope = $analyzerScope }
			@{ Path = 'd365bap.tools/tests/pester-PSScriptAnalyzer.ps1'; Scope = $analyzerScope }
			@{ Path = 'd365bap.tools/tests/behavior/Sample.Tests.ps1'; Scope = $compileScope }
		)) {
		Write-Fixture $case.Path 'changed harness'
		$head = Commit 'test harness change'
		$plan = Get-Plan $base $head
		Assert-Scope $plan $case.Scope "Test harness change ($($case.Path))" -Gate
		if ($case.Path -match '/behavior/') {
			Assert-True ($plan.BehaviorTests -eq $true) "Behavior harness change must set BehaviorTests: $($case.Path)"
		}
		else {
			Assert-True ($plan.BehaviorTests -eq $false) "Non-behavior harness change must leave BehaviorTests false: $($case.Path)"
		}
		if ($case.Path -ceq 'd365bap.tools/tests/functions/Get-Example.Tests.ps1') { Assert-GeneratedRejected $base $head }
		Reset-Base
	}

	# Behavior suites only run when their fixtures or covered FinOps sources change.
	Write-Fixture 'd365bap.tools/functions/Get-PpacFinOpsAsset.ps1' 'function Get-PpacFinOpsAsset { 1 }'
	$head = Commit 'behavior-covered public function'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $selectiveScope 'FinOps asset function change'
	Assert-True ($plan.BehaviorTests -eq $true) 'Get-PpacFinOpsAsset must enable BehaviorTests.'
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' 'function Get-Example { 2 }'
	$head = Commit 'unrelated public function'
	$plan = Get-Plan $base $head
	Assert-Scope $plan $selectiveScope 'Unrelated public function change'
	Assert-True ($plan.BehaviorTests -eq $false) 'Unrelated public functions must leave BehaviorTests false.'
	Reset-Base

	# Shared module code keeps the full module coverage and both full scans.
	foreach ($path in @(
			'd365bap.tools/d365bap.tools.psd1'
			'd365bap.tools/d365bap.tools.psm1'
		)) {
		Write-Fixture $path 'function Get-Shared { 5 }'
		$head = Commit 'shared module change'
		$plan = Get-Plan $base $head
		Assert-Scope $plan $moduleScope "Shared module change ($path)"
		Assert-True ($plan.Mode -ceq 'full') "Shared module code must report the compatibility mode full: $path"
		Reset-Base
	}

	$null = Git @('rm', '-q', 'd365bap.tools/functions/Get-Example.ps1')
	$head = Commit 'deletion'
	Assert-Scope (Get-Plan $base $head) $moduleScope 'Source deletion'
	Reset-Base

	$null = Git @('mv', 'd365bap.tools/functions/Get-Example.ps1', 'd365bap.tools/functions/Get-Renamed.ps1')
	$head = Commit 'rename'
	Assert-Scope (Get-Plan $base $head) $moduleScope 'Source rename'
	Reset-Base

	# Unknown or shared paths keep the conservative fallback: full module
	# coverage and both scans, never a silently narrower scope.
	foreach ($path in @('build/config.json', 'build/Merge-FormatPs1Xml.ps1', 'build/update-docs.ps1', 'install.ps1', '.github/workflows/build-v2.yml', 'library/unknown.json', 'docs/AGENTS.md', 'docs/unknown.yml', 'd365bap.tools/functions/Get-Weird[1].ps1')) {
		Write-Fixture $path 'changed'
		$head = Commit 'shared change'
		Assert-Scope (Get-Plan $base $head) $moduleScope "Shared path change ($path)"
		Reset-Base
	}

	# Every explicit infrastructure pattern selects the regression suites on its
	# own and leaves the module jobs alone: changing tooling cannot change the
	# module, so the module suites stay off.
	foreach ($path in @(
			'build/ps1-lint/internal/Get-Example.ps1',
			'build/ps1-lint/README.md',
			'build/Get-Example.ps1',
			'build/Invoke-Example.ps1',
			'build/Test-Example.ps1',
			'build/Install-RequiredModules.ps1',
			'build/Install-Prek.ps1',
			'build/ModuleCacheRequirements.json',
			'build/ToolCacheRequirements.json',
			'build/ci-stubs/Az.Accounts/99.0.0/Az.Accounts.psd1',
			'prek.toml',
			'.github/workflows/validate.yml'
		)) {
		Write-Fixture $path 'changed'
		$head = Commit 'infrastructure change'
		$plan = Get-Plan $base $head
		Assert-Scope $plan $infrastructureScope "Infrastructure change ($path)" -Gate:($path -ceq 'prek.toml')
		Assert-True ($plan.Mode -ceq 'full') "An infrastructure change must report the compatibility mode full: $path"
		Assert-True ($plan.InfrastructurePaths.Count -eq 1 -and $plan.InfrastructurePaths[0] -ceq $path) "Infrastructure paths must name the changed tooling: $path"
		Reset-Base
	}

	# An infrastructure change next to real module code keeps the module tests:
	# the flags are independent, so the union still covers the shared code.
	Write-Fixture 'build/Test-Example.ps1' 'changed'
	Write-Fixture 'd365bap.tools/internal/functions/Get-Shared.ps1' @'
function Get-Shared {
	7
}
'@
	$head = Commit 'infrastructure and shared code'
	Assert-Scope (Get-Plan $base $head) $fullScope 'Infrastructure and shared module change' -Gate
	Reset-Base

	Write-Fixture 'build/Test-Example.ps1' 'changed'
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
function Get-Example {
	3
}
'@
	$head = Commit 'infrastructure and public function'
	$plan = Get-Plan $base $head
	Assert-Scope $plan @{ Mode = 'full'; ModuleTests = $false; AnalyzerScans = $false; SelectiveTests = $true; CompiledImport = $true; InfrastructureChange = $true; Scope = 'selective+compiled-import+infrastructure' } 'Infrastructure and public function change'
	Reset-Base

	# Deleting or renaming away infrastructure tooling is a change to it.
	Write-Fixture 'build/Get-Temporary.ps1' 'function Get-Temporary { 1 }'
	$infrastructureBase = Commit 'infrastructure base'
	$null = Git @('rm', '-q', 'build/Get-Temporary.ps1')
	$head = Commit 'remove infrastructure'
	$plan = Get-Plan $infrastructureBase $head
	Assert-True ($plan.InfrastructureChange -eq $true -and $plan.InfrastructurePaths -contains 'build/Get-Temporary.ps1') 'Deleting infrastructure must set the flag.'
	Assert-Scope $plan $infrastructureScope 'Deleted infrastructure'
	Reset-Base

	Write-Fixture 'build/Get-Temporary.ps1' 'function Get-Temporary { 1 }'
	$infrastructureBase = Commit 'infrastructure base for rename'
	$null = New-Item -ItemType Directory -Path (Join-Path $root 'tools') -Force
	$null = Git @('mv', 'build/Get-Temporary.ps1', 'tools/Get-Temporary.ps1')
	$head = Commit 'move infrastructure out'
	$plan = Get-Plan $infrastructureBase $head
	Assert-True ($plan.InfrastructureChange -eq $true -and $plan.InfrastructurePaths -contains 'build/Get-Temporary.ps1') 'Renaming infrastructure away must set the flag.'
	Assert-Scope $plan $fullScope 'Infrastructure moved to an unknown path'
	Reset-Base

	Write-Fixture 'd365bap.tools/tests/functions/Get-Example.Tests.ps1' 'Describe "Generated" { It "fails" { 1 | Should -Be 2 } }'
	$null = Git @('add', '-A')
	$null = Git @('-c', 'user.name=github-actions[bot]', '-c', 'user.email=bot@example.invalid', 'commit', '-qm', 'spoofed bot')
	Assert-GeneratedRejected $base ((Git @('rev-parse', 'HEAD')).Trim())
	Reset-Base
	$plan = Get-Plan $base $base
	Assert-Scope $plan $fullScope 'Empty diff'
	Assert-True ($plan.Reasons.Count -gt 0) 'The fallback must explain itself.'

	Write-Fixture 'README.md' 'base branch change'
	$divergedBase = Commit 'base branch'
	Reset-Base
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' @'
function Get-Example {
	4
}
'@
	$head = Commit 'head branch'
	$plan = Get-Plan $divergedBase $head
	Assert-Scope $plan $selectiveScope 'Diverged public function'
	Assert-True ($plan.MergeBase -eq $base) 'Diff must use merge base for diverged branches.'

	# Result-gate combinations: exhaustive over what the plan can emit, and
	# fail-closed for every job the plan requires. A skipped or missing required
	# job can never pass, and an unrequired job that ran fails as well.
	$docsGate = @{ Scope = 'docs'; ModuleTests = 'false'; AnalyzerScans = 'false'; SelectiveTests = 'false'; CompiledImport = 'false'; CompiledHash = ''; CompiledScope = ''; General = 'skipped'; Public = 'skipped'; Internal = 'skipped'; Selective = 'skipped'; Compiled = 'skipped' }
	$compileGate = @{ Scope = 'compiled-import'; ModuleTests = 'false'; AnalyzerScans = 'false'; SelectiveTests = 'false'; CompiledImport = 'true'; CompiledHash = ('A' * 64); CompiledScope = 'compiled-import'; General = 'skipped'; Public = 'skipped'; Internal = 'skipped'; Selective = 'skipped' }
	$selectiveGate = @{ Scope = 'selective+compiled-import'; ModuleTests = 'false'; AnalyzerScans = 'false'; SelectiveTests = 'true'; CompiledImport = 'true'; SelectiveHash = ('A' * 64); SelectiveScope = 'selective+compiled-import'; CompiledHash = ('A' * 64); CompiledScope = 'selective+compiled-import'; General = 'skipped'; Public = 'skipped'; Internal = 'skipped'; Selective = 'success' }
	$moduleTestsGate = @{ Scope = 'module-tests+compiled-import'; ModuleTests = 'true'; AnalyzerScans = 'false'; SelectiveTests = 'false'; CompiledImport = 'true'; CompiledHash = ('A' * 64); CompiledScope = 'module-tests+compiled-import'; General = 'success'; Public = 'skipped'; Internal = 'skipped'; Selective = 'skipped' }
	$analyzerGate = @{ Scope = 'analyzer-scans+compiled-import'; ModuleTests = 'false'; AnalyzerScans = 'true'; SelectiveTests = 'false'; CompiledImport = 'true'; CompiledHash = ('A' * 64); CompiledScope = 'analyzer-scans+compiled-import'; General = 'skipped'; Public = 'success'; Internal = 'success'; Selective = 'skipped' }
	$infrastructureGate = @{ Scope = 'compiled-import+infrastructure'; ModuleTests = 'false'; AnalyzerScans = 'false'; SelectiveTests = 'false'; CompiledImport = 'true'; InfrastructureChange = 'true'; InfrastructureResult = 'success'; CompiledHash = ('A' * 64); CompiledScope = 'compiled-import+infrastructure'; General = 'skipped'; Public = 'skipped'; Internal = 'skipped'; Selective = 'skipped' }
	$fullGate = @{ Scope = 'module-tests+analyzer-scans+compiled-import+infrastructure'; ModuleTests = 'true'; AnalyzerScans = 'true'; SelectiveTests = 'false'; CompiledImport = 'true'; InfrastructureChange = 'true'; InfrastructureResult = 'success'; CompiledHash = ('A' * 64); CompiledScope = 'module-tests+analyzer-scans+compiled-import+infrastructure'; General = 'success'; Public = 'success'; Internal = 'success'; Selective = 'skipped' }

	Assert-Gate $docsGate $true 'a documentation-only scope'
	Assert-Gate $docsGate $true 'a formatting-only scope'
	Assert-Gate $selectiveGate $true 'a public-function scope'
	Assert-Gate $moduleTestsGate $true 'a module-test scope'
	Assert-Gate $analyzerGate $true 'an analyzer-harness scope'
	Assert-Gate $infrastructureGate $true 'an infrastructure scope'
	Assert-Gate $fullGate $true 'a full scope'

	# Each job's plan flag is checked in both directions.
	$jobCase = @(
		@{ Job = 'General'; Required = $moduleTestsGate; Unrequired = $docsGate }
		@{ Job = 'Public'; Required = $analyzerGate; Unrequired = $docsGate }
		@{ Job = 'Internal'; Required = $analyzerGate; Unrequired = $docsGate }
		@{ Job = 'Selective'; Required = $selectiveGate; Unrequired = $docsGate + @{ SelectiveHash = ''; SelectiveScope = '' } }
		@{ Job = 'Compiled'; Required = $compileGate; Unrequired = $docsGate }
		@{ Job = 'InfrastructureResult'; Required = $infrastructureGate; Unrequired = $compileGate }
	)
	foreach ($case in $jobCase) {
		foreach ($state in @(
				@{ Value = 'skipped'; Label = 'a skipped' }
				@{ Value = $null; Label = 'a missing' }
				@{ Value = 'failure'; Label = 'a failed' }
			)) {
			Assert-Gate (New-GateCase $case.Required $case.Job $state.Value) $false "$($state.Label) $($case.Job) job that the plan requires"
		}
		Assert-Gate (New-GateCase $case.Unrequired $case.Job 'success') $false "a $($case.Job) job that ran while the plan did not ask for it"
	}

	Assert-Gate @{ CompiledImport = 'false' } $false 'a partial scope without the compiled-import job'
	Assert-Gate @{ SelectiveTests = 'true'; SelectiveHash = ('B' * 64); SelectiveScope = 'selective+compiled-import'; Selective = 'success' } $false 'a mismatched selective plan'
	Assert-Gate @{ SelectiveTests = 'true'; SelectiveHash = ('A' * 64); SelectiveScope = 'module-tests'; Selective = 'success' } $false 'a mismatched selective scope'
	Assert-Gate @{ CompiledHash = ('B' * 64) } $false 'a mismatched compiled plan'
	Assert-Gate @{ CompiledScope = 'docs' } $false 'a mismatched compiled scope'
	Assert-Gate @{ CompiledHash = ''; CompiledScope = '' } $false 'a compiled job without a plan hash'
	Assert-Gate @{ PlanHash = 'not-a-hash' } $false 'an invalid plan hash'
	Assert-Gate @{ ModuleTests = 'yes' } $false 'an invalid module-tests flag'
	Assert-Gate @{ AnalyzerScans = $null } $false 'a missing analyzer-scans flag'
	Assert-Gate @{ InfrastructureChange = 'yes' } $false 'an invalid infrastructure flag'
	Assert-Gate @{ InfrastructureChange = $null } $false 'a missing infrastructure flag'
	Assert-Gate @{ Lint = 'failure' } $false 'failed lint'
	Assert-Gate @{ ChangeResult = 'failure' } $false 'failed change detection'
	Assert-Gate @{ Scope = $null } $false 'a missing scope'

	# The infrastructure runner must execute every declared suite. A missing
	# suite, or a suite that exits non-zero, cannot report success.
	$runnerFixture = Join-Path ([IO.Path]::GetTempPath()) ('infra-runner-' + [guid]::NewGuid().ToString('N'))
	$runner = Join-Path $runnerFixture 'Invoke-InfrastructureValidation.ps1'
	$infrastructureSuites = @('Test-PRValidationPlan', 'Test-Ps1LintScope', 'Test-CiLintPlan', 'Test-PrekInstall', 'Test-Ps1FormatXml', 'Test-SelectiveValidation', 'Test-SelectedStringsHandling', 'Test-Ps1LintCorrectness', 'Test-Ps1LintBatch', 'Test-Ps1AnalysisCache')
	try {
		$null = New-Item -ItemType Directory -Path $runnerFixture -Force
		Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-InfrastructureValidation.ps1') -Destination $runner
		$emptyOutput = @(& $pwsh -NoProfile -NonInteractive -File $runner 2>&1 | ForEach-Object { "$_" }) -join "`n"
		Assert-True ($LASTEXITCODE -ne 0 -and $emptyOutput -match 'missing') 'A missing infrastructure suite must fail the run.'

		foreach ($suite in $infrastructureSuites) { Set-Content -LiteralPath (Join-Path $runnerFixture "$suite.ps1") -Value 'exit 0' -Encoding utf8 }
		$passOutput = @(& $pwsh -NoProfile -NonInteractive -File $runner 2>&1 | ForEach-Object { "$_" }) -join "`n"
		Assert-True ($LASTEXITCODE -eq 0 -and $passOutput -match '10 suites') "The runner must execute all ten suites: $passOutput"

		Set-Content -LiteralPath (Join-Path $runnerFixture 'Test-Ps1LintBatch.ps1') -Value 'exit 1' -Encoding utf8
		$skipOutput = @(& $pwsh -NoProfile -NonInteractive -File $runner 2>&1 | ForEach-Object { "$_" }) -join "`n"
		Assert-True ($LASTEXITCODE -ne 0 -and $skipOutput -match 'Test-Ps1LintBatch') 'A failing infrastructure suite must fail the run.'
	}
	finally {
		if (Test-Path -LiteralPath $runnerFixture) { Remove-Item -LiteralPath $runnerFixture -Recurse -Force }
	}

	$badOut = Join-Path $root 'bad.json'
	$failed = $false
	try { & $detector -BaseSha 'not-a-sha' -HeadSha $head -OutputPath $badOut -RepositoryPath $root } catch { $failed = $true }
	Assert-True ($failed -and -not (Test-Path -LiteralPath $badOut)) 'Invalid revisions must fail closed.'
	Write-Host 'PR validation plan regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) {
		$resolved = (Resolve-Path -LiteralPath $root).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -or
			[IO.Path]::GetFileName($resolved) -notmatch '^pr-plan-tests-[0-9a-f]{32}$') { throw 'Unexpected fixture cleanup path.' }
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
