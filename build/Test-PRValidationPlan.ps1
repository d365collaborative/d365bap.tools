[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('pr-plan-tests-' + [guid]::NewGuid().ToString('N'))
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$detector = Join-Path $PSScriptRoot 'Get-PRValidationPlan.ps1'

function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Git([string[]] $Arguments) {
	$output = @(& $gitExe -C $root @Arguments 2>&1)
	if ($LASTEXITCODE -ne 0) { throw "git $Arguments failed: $output" }
	return ($output -join "`n")
}
function Write-Fixture([string] $Path, [string] $Content) {
	$file = Join-Path $root $Path
	$null = New-Item -ItemType Directory -Path (Split-Path $file) -Force
	Set-Content -LiteralPath $file -Value $Content -Encoding utf8
}
function Commit([string] $Message) {
	$null = Git @('add', '-A')
	$null = Git @('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', $Message)
	return (Git @('rev-parse', 'HEAD')).Trim()
}
function Get-Plan([string] $Base, [string] $Head) {
	$out = Join-Path ([IO.Path]::GetTempPath()) ('pr-plan-' + [guid]::NewGuid().ToString('N') + '.json')
	try {
		& $detector -BaseSha $Base -HeadSha $Head -OutputPath $out -RepositoryPath $root
		return Get-Content -Raw -LiteralPath $out | ConvertFrom-Json
	}
	finally { Remove-Item -LiteralPath $out -Force -ErrorAction Ignore }
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
try {
	$null = New-Item -ItemType Directory -Path $root -Force
	$null = Git @('init', '-q')
	Write-Fixture 'README.md' 'readme'
	Write-Fixture 'docs/example.md' 'docs'
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' 'function Get-Example { 1 }'
	Write-Fixture 'd365bap.tools/tests/functions/Get-Example.Tests.ps1' 'test'
	$base = Commit 'base'

	Write-Fixture 'docs/example.md' 'changed docs'
	$head = Commit 'docs'
	$plan = Get-Plan $base $head
	Assert-True ($plan.Mode -eq 'docs' -and $plan.PublicPaths.Count -eq 0) 'Docs must select docs mode.'
	Reset-Base

	foreach ($path in @('wiki/example.md', 'learning/course/chapter.md', 'd365bap.tools/readme.md', 'd365bap.tools/changelog.md')) {
		Write-Fixture $path 'documentation'
		$head = Commit 'additional documentation'
		Assert-True ((Get-Plan $base $head).Mode -eq 'docs') "Recognized documentation must select docs mode: $path"
		Reset-Base
	}

	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' 'function Get-Example { 2 }'
	Write-Fixture 'README.md' 'also changed'
	$head = Commit 'public and docs'
	$plan = Get-Plan $base $head
	Assert-True ($plan.Mode -eq 'selective') 'Public modifications must select selective mode.'
	Assert-True ($plan.PublicPaths.Count -eq 1 -and $plan.PublicPaths[0] -ceq 'd365bap.tools/functions/Get-Example.ps1') 'The changed source must be included.'
	Reset-Base

	Write-Fixture 'd365bap.tools/functions/Get-New.ps1' 'function Get-New { 1 }'
	$head = Commit 'unmatched addition'
	$plan = Get-Plan $base $head
	Assert-True ($plan.Mode -eq 'selective' -and $plan.PublicPaths[0] -ceq 'd365bap.tools/functions/Get-New.ps1') 'New functions without generated tests must select selective validation.'
	Reset-Base

	$null = Git @('rm', '-q', 'd365bap.tools/functions/Get-Example.ps1')
	$head = Commit 'deletion'
	Assert-True ((Get-Plan $base $head).Mode -eq 'full') 'Source deletion must select full validation.'
	Reset-Base

	$null = Git @('mv', 'd365bap.tools/functions/Get-Example.ps1', 'd365bap.tools/functions/Get-Renamed.ps1')
	$head = Commit 'rename'
	Assert-True ((Get-Plan $base $head).Mode -eq 'full') 'Source rename must select full validation.'
	Reset-Base

	foreach ($path in @('d365bap.tools/functions/Get-Weird[1].ps1', 'd365bap.tools/internal/functions/Get-Shared.ps1', 'd365bap.tools/tests/functions/Get-Example.Tests.ps1', 'build/config.json', 'build/Test-Behavior.ps1', 'd365bap.tools/tests/behavior/Shared.Tests.ps1', 'docs/AGENTS.md', 'wiki/AGENTS.md', 'learning/course/AGENTS.md', 'docs/unknown.yml', 'wiki/unknown.yml', 'learning/course/unknown.yml')) {
		Write-Fixture $path 'changed'
		$head = Commit 'shared change'
		Assert-True ((Get-Plan $base $head).Mode -eq 'full') "Shared, test, config, or instruction change must select full: $path"
		if ($path -eq 'd365bap.tools/tests/functions/Get-Example.Tests.ps1') { Assert-GeneratedRejected $base $head }
		Reset-Base
	}
	Write-Fixture 'd365bap.tools/tests/functions/Get-Example.Tests.ps1' 'Describe "Generated" { It "fails" { 1 | Should -Be 2 } }'
	$null = Git @('add', '-A')
	$null = Git @('-c', 'user.name=github-actions[bot]', '-c', 'user.email=bot@example.invalid', 'commit', '-qm', 'spoofed bot')
	Assert-GeneratedRejected $base ((Git @('rev-parse', 'HEAD')).Trim())
	Reset-Base
	Assert-True ((Get-Plan $base $base).Mode -eq 'full') 'Empty diff must select full validation.'

	Write-Fixture 'README.md' 'base branch change'
	$divergedBase = Commit 'base branch'
	Reset-Base
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' 'function Get-Example { 3 }'
	$head = Commit 'head branch'
	$plan = Get-Plan $divergedBase $head
	Assert-True ($plan.Mode -eq 'selective' -and $plan.MergeBase -eq $base) 'Diff must use merge base for diverged branches.'

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
