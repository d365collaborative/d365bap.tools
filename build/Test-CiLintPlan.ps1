[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ci-lint-plan-' + [guid]::NewGuid().ToString('N'))
$planScript = Join-Path $PSScriptRoot 'Get-CiLintPlan.ps1'
$analyzerScript = Join-Path $PSScriptRoot 'ps1-lint/psscriptanalyzer/Run.ps1'
$pwsh = (Get-Process -Id $PID).Path
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Assert-Set([string[]] $Actual, [string[]] $Expected, [string] $Label) {
	$colActualSorted = @($Actual | Sort-Object -Unique)
	$colExpectedSorted = @($Expected | Sort-Object -Unique)
	if (($colActualSorted -join '|') -ne ($colExpectedSorted -join '|')) {
		throw "$Label mismatch. Expected [$($colExpectedSorted -join ', ')], got [$($colActualSorted -join ', ')]."
	}
}

function Invoke-Git([string[]] $Arguments) {
	$colOutput = @(& $gitExe -C $root @Arguments 2>&1)
	if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $colOutput" }
	($colOutput -join "`n").Trim()
}

function Write-Fixture([string] $Path, [string] $Content) {
	$file = Join-Path $root $Path
	$null = New-Item -ItemType Directory -Path (Split-Path $file) -Force
	Set-Content -LiteralPath $file -Value $Content -Encoding utf8
}

function Commit([string] $Message) {
	$null = Invoke-Git @('add', '-A')
	$null = Invoke-Git @('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', $Message)
	Invoke-Git @('rev-parse', 'HEAD')
}

function Get-Plan([string] $Base, [string] $Head) {
	$out = Join-Path ([IO.Path]::GetTempPath()) ('ci-lint-plan-' + [guid]::NewGuid().ToString('N') + '.json')
	try {
		& $planScript -BaseSha $Base -HeadSha $Head -OutputPath $out -RepositoryPath $root | Out-Null
		Get-Content -Raw -LiteralPath $out | ConvertFrom-Json
	}
	finally { Remove-Item -LiteralPath $out -Force -ErrorAction Ignore }
}

function Invoke-Analyzer([string[]] $RelativeFiles) {
	Push-Location $root
	try {
		$output = & $pwsh -NoProfile -NonInteractive -File $analyzerScript @RelativeFiles 2>&1 | Out-String
		[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
	}
	finally { Pop-Location }
}

function Reset-Base { $null = Invoke-Git @('reset', '--hard', $script:base) }

try {
	$null = New-Item -ItemType Directory -Path $root -Force
	$null = Invoke-Git @('init', '-q')

	Write-Fixture 'README.md' '# readme'
	Write-Fixture 'config/settings.json' '{"value":1}'
	Write-Fixture 'config/settings.yml' "name: base`n"
	Write-Fixture '.github/workflows/validate.yml' @'
name: validate
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
    - run: echo ok
'@
	# This file is never touched. Its lint violations must never become PR blockers.
	Write-Fixture 'd365bap.tools/functions/Get-Untouched.ps1' @'
function Get-Untouched {
    param()

    Write-Host 'untouched violation'
}
'@
	Write-Fixture 'build/Run-Old.ps1' "Get-Date`n"
	$base = Commit 'base'

	# Documentation changes only reach the cheap hooks.
	Write-Fixture 'README.md' '# readme changed'
	$head = Commit 'docs'
	$plan = Get-Plan $base $head
	Assert-Set $plan.CheapFiles @('README.md') 'Documentation cheap files'
	Assert-Set $plan.PowerShellFiles @() 'Documentation PowerShell files'
	Assert-Set $plan.WorkflowFiles @() 'Documentation workflow files'
	Reset-Base

	# JSON changes reach check-json and the cheap whitespace hooks.
	Write-Fixture 'config/settings.json' '{"value":2}'
	$head = Commit 'json'
	$plan = Get-Plan $base $head
	Assert-Set $plan.CheapFiles @('config/settings.json') 'JSON cheap files'
	Assert-Set $plan.PowerShellFiles @() 'JSON PowerShell files'
	Reset-Base

	# YAML changes reach check-yaml without being workflow files.
	Write-Fixture 'config/settings.yml' "name: changed`n"
	$head = Commit 'yaml'
	$plan = Get-Plan $base $head
	Assert-Set $plan.CheapFiles @('config/settings.yml') 'YAML cheap files'
	Assert-Set $plan.WorkflowFiles @() 'YAML workflow files'
	Reset-Base

	# A touched workflow reaches check-yaml and actionlint.
	Write-Fixture '.github/workflows/validate.yml' @'
name: validate
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
    - run: echo changed
'@
	$head = Commit 'workflow'
	$plan = Get-Plan $base $head
	Assert-Set $plan.CheapFiles @('.github/workflows/validate.yml') 'Workflow cheap files'
	Assert-Set $plan.WorkflowFiles @('.github/workflows/validate.yml') 'Touched workflow files'
	Reset-Base

	# A touched public function is selected and its violation fails the analyzer.
	Write-Fixture 'd365bap.tools/functions/Get-Untouched.ps1' @'
function Get-Untouched {
    param()

    Write-Host 'changed violation'
}
'@
	$head = Commit 'public change'
	$plan = Get-Plan $base $head
	Assert-Set $plan.PowerShellFiles @('d365bap.tools/functions/Get-Untouched.ps1') 'Public PowerShell files'
	Assert-Set $plan.CheapFiles @('d365bap.tools/functions/Get-Untouched.ps1') 'Public cheap files'
	$result = Invoke-Analyzer @($plan.PowerShellFiles)
	Assert-True ($result.ExitCode -ne 0) "A touched public violation must fail the analyzer: $($result.Output)"
	Reset-Base

	# A touched internal function is selected and its violation fails the analyzer.
	Write-Fixture 'd365bap.tools/internal/functions/Set-Changed.ps1' @'
function Set-Changed {
    param()

    Write-Host 'changed violation'
}
'@
	$head = Commit 'internal change'
	$plan = Get-Plan $base $head
	Assert-Set $plan.PowerShellFiles @('d365bap.tools/internal/functions/Set-Changed.ps1') 'Internal PowerShell files'
	$result = Invoke-Analyzer @($plan.PowerShellFiles)
	Assert-True ($result.ExitCode -ne 0) "A touched internal violation must fail the analyzer: $($result.Output)"
	Reset-Base

	# A clean touched script passes while the untouched violating file stays out of scope.
	Write-Fixture 'build/Run-Old.ps1' "Get-Date -Format 'o'`n"
	$head = Commit 'clean script'
	$plan = Get-Plan $base $head
	Assert-Set $plan.PowerShellFiles @('build/Run-Old.ps1') 'Clean PowerShell files'
	$result = Invoke-Analyzer @($plan.PowerShellFiles)
	Assert-True ($result.ExitCode -eq 0) "An untouched violation must not fail the selected clean file: $($result.Output)"
	Reset-Base

	# Module manifests are PowerShell files even though custom rules do not run on them.
	Write-Fixture 'd365bap.tools/d365bap.tools.psm1' "Get-Date`n"
	$head = Commit 'module'
	$plan = Get-Plan $base $head
	Assert-Set $plan.PowerShellFiles @('d365bap.tools/d365bap.tools.psm1') 'Module PowerShell files'
	Reset-Base

	# A deletion has no file to check.
	$null = Invoke-Git @('rm', '-q', 'build/Run-Old.ps1')
	$head = Commit 'delete'
	$plan = Get-Plan $base $head
	Assert-Set $plan.CheapFiles @() 'Deletion cheap files'
	Assert-Set $plan.PowerShellFiles @() 'Deletion PowerShell files'
	Reset-Base

	# A rename checks the new path only.
	$null = Invoke-Git @('mv', 'build/Run-Old.ps1', 'build/Run-New.ps1')
	$head = Commit 'rename'
	$plan = Get-Plan $base $head
	Assert-Set $plan.PowerShellFiles @('build/Run-New.ps1') 'Renamed PowerShell files'
	Reset-Base

	# A diverged base must not add base-branch files to the plan.
	Write-Fixture 'README.md' '# base branch change'
	$divergedBase = Commit 'base branch'
	Reset-Base
	Write-Fixture 'config/settings.json' '{"value":3}'
	$head = Commit 'head branch'
	$plan = Get-Plan $divergedBase $head
	Assert-True ($plan.MergeBase -eq $base) 'The plan must use the merge base.'
	Assert-Set $plan.CheapFiles @('config/settings.json') 'Diverged cheap files'

	$badOut = Join-Path $root 'bad.json'
	$failed = $false
	try { & $planScript -BaseSha 'not-a-sha' -HeadSha $head -OutputPath $badOut -RepositoryPath $root } catch { $failed = $true }
	Assert-True ($failed -and -not (Test-Path -LiteralPath $badOut)) 'Invalid revisions must fail closed.'

	Write-Host 'CI lint plan regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) {
		$resolved = (Resolve-Path -LiteralPath $root).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -or
			[IO.Path]::GetFileName($resolved) -notmatch '^ci-lint-plan-[0-9a-f]{32}$') { throw 'Unexpected fixture cleanup path.' }
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
