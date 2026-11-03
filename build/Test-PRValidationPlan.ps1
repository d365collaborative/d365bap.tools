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
	$gate = Join-Path $PSScriptRoot 'Invoke-ValidationResultGate.ps1'
	$hashDefault = [ordered]@{
		Lint                 = 'success'
		ChangeResult         = 'success'
		Mode                 = 'full'
		InfrastructureChange = 'false'
		PlanHash             = ('A' * 64)
		SelectiveHash        = ('A' * 64)
		CompiledHash         = ('A' * 64)
		SelectiveMode        = 'full'
		CompiledMode         = 'full'
		General              = 'success'
		Public               = 'success'
		Internal             = 'success'
		Selective            = 'success'
		Compiled             = 'success'
		InfrastructureResult = 'skipped'
	}
	foreach ($itemKey in $Overrides.Keys) { $hashDefault[$itemKey] = $Overrides[$itemKey] }
	$arguments = @()
	foreach ($itemKey in $hashDefault.Keys) {
		# A null override omits the parameter, which simulates a missing job result.
		if ($null -eq $hashDefault[$itemKey]) { continue }
		$arguments += "-$itemKey"
		$arguments += [string] $hashDefault[$itemKey]
	}
	$output = @(& $pwsh -NoProfile -NonInteractive -File $gate @arguments 2>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
function Assert-Gate([hashtable] $Overrides, [bool] $Pass, [string] $Label) {
	$result = Invoke-ResultGate $Overrides
	if ($Pass -and $result.ExitCode -ne 0) { throw "Result gate rejected $Label`: $($result.Output)" }
	if (-not $Pass -and $result.ExitCode -eq 0) { throw "Result gate accepted $Label" }
}
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
	Assert-True ($plan.InfrastructureChange -eq $false -and $plan.InfrastructurePaths.Count -eq 0) 'Docs must not select the infrastructure job.'
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
	Assert-True ($plan.InfrastructureChange -eq $false) 'A public-function change must not run the infrastructure suites.'
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

	# Every explicit infrastructure pattern must set the flag on its own. The
	# flag selects the infrastructure-tests job, so a miss silently drops the
	# ten regression suites from that pull request.
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
			'prek.toml',
			'.github/workflows/validate.yml'
		)) {
		Write-Fixture $path 'changed'
		$head = Commit 'infrastructure change'
		$plan = Get-Plan $base $head
		Assert-True ($plan.Mode -eq 'full') "Infrastructure change must select full validation: $path"
		Assert-True ($plan.InfrastructureChange -eq $true) "Infrastructure change must set the flag: $path"
		Assert-True ($plan.InfrastructurePaths.Count -eq 1 -and $plan.InfrastructurePaths[0] -ceq $path) "Infrastructure paths must name the changed tooling: $path"
		Reset-Base
	}

	# Tooling outside the suites' inputs stays out of the infrastructure job;
	# the explicit set is deliberate rather than "any build file".
	foreach ($path in @('build/config.json', 'build/Merge-FormatPs1Xml.ps1', 'build/update-docs.ps1', '.github/workflows/build-v2.yml')) {
		Write-Fixture $path 'changed'
		$head = Commit 'non-infrastructure build change'
		$plan = Get-Plan $base $head
		Assert-True ($plan.Mode -eq 'full') "Build change outside the suite inputs must select full validation: $path"
		Assert-True ($plan.InfrastructureChange -eq $false) "Build change outside the suite inputs must not set the flag: $path"
		Reset-Base
	}

	# Deleting or renaming away infrastructure tooling is a change to it.
	Write-Fixture 'build/Get-Temporary.ps1' 'function Get-Temporary { 1 }'
	$infrastructureBase = Commit 'infrastructure base'
	$null = Git @('rm', '-q', 'build/Get-Temporary.ps1')
	$head = Commit 'remove infrastructure'
	$plan = Get-Plan $infrastructureBase $head
	Assert-True ($plan.InfrastructureChange -eq $true -and $plan.InfrastructurePaths -contains 'build/Get-Temporary.ps1') 'Deleting infrastructure must set the flag.'
	Reset-Base

	Write-Fixture 'build/Get-Temporary.ps1' 'function Get-Temporary { 1 }'
	$infrastructureBase = Commit 'infrastructure base for rename'
	$null = New-Item -ItemType Directory -Path (Join-Path $root 'tools') -Force
	$null = Git @('mv', 'build/Get-Temporary.ps1', 'tools/Get-Temporary.ps1')
	$head = Commit 'move infrastructure out'
	$plan = Get-Plan $infrastructureBase $head
	Assert-True ($plan.InfrastructureChange -eq $true -and $plan.InfrastructurePaths -contains 'build/Get-Temporary.ps1') 'Renaming infrastructure away must set the flag.'
	Reset-Base

	Write-Fixture 'd365bap.tools/tests/functions/Get-Example.Tests.ps1' 'Describe "Generated" { It "fails" { 1 | Should -Be 2 } }'
	$null = Git @('add', '-A')
	$null = Git @('-c', 'user.name=github-actions[bot]', '-c', 'user.email=bot@example.invalid', 'commit', '-qm', 'spoofed bot')
	Assert-GeneratedRejected $base ((Git @('rev-parse', 'HEAD')).Trim())
	Reset-Base
	$plan = Get-Plan $base $base
	Assert-True ($plan.Mode -eq 'full') 'Empty diff must select full validation.'
	Assert-True ($plan.InfrastructureChange -eq $true) 'An unreadable diff must run the infrastructure suites.'

	Write-Fixture 'README.md' 'base branch change'
	$divergedBase = Commit 'base branch'
	Reset-Base
	Write-Fixture 'd365bap.tools/functions/Get-Example.ps1' 'function Get-Example { 3 }'
	$head = Commit 'head branch'
	$plan = Get-Plan $divergedBase $head
	Assert-True ($plan.Mode -eq 'selective' -and $plan.MergeBase -eq $base) 'Diff must use merge base for diverged branches.'
	Assert-True ($plan.InfrastructureChange -eq $false) 'A diverged public-function change must not run the infrastructure suites.'

	# Result-gate combinations: exhaustive over what the plan can emit, and
	# fail-closed for an infrastructure job that is skipped or missing while the
	# flag is true. A skipped infrastructure job is accepted only when the plan
	# says no infrastructure changed.
	$fullSuccess = @{ General = 'success'; Public = 'success'; Internal = 'success'; Selective = 'success'; Compiled = 'success' }
	$pruned = @{ General = 'skipped'; Public = 'skipped'; Internal = 'skipped'; Selective = 'success'; Compiled = 'success' }
	$infrastructureSuccess = @{ InfrastructureChange = 'true'; InfrastructureResult = 'success' }
	$selectiveContext = @{ Mode = 'selective'; SelectiveMode = 'selective'; CompiledMode = 'selective' }
	$docsContext = @{ Mode = 'docs'; SelectiveMode = 'docs'; CompiledMode = 'docs' }

	Assert-Gate $fullSuccess $true 'full mode without an infrastructure change'
	Assert-Gate $infrastructureSuccess $true 'full mode with a passing infrastructure job'
	Assert-Gate ($pruned + $selectiveContext) $true 'selective mode'
	Assert-Gate ($pruned + $docsContext) $true 'docs mode'
	Assert-Gate @{ InfrastructureChange = 'true'; InfrastructureResult = 'skipped' } $false 'a skipped infrastructure job while the flag is true'
	Assert-Gate @{ InfrastructureChange = 'true'; InfrastructureResult = $null } $false 'a missing infrastructure job while the flag is true'
	Assert-Gate @{ InfrastructureChange = 'true'; InfrastructureResult = 'failure' } $false 'a failed infrastructure job while the flag is true'
	Assert-Gate @{ InfrastructureResult = 'success' } $false 'an infrastructure job that ran while the flag is false'
	Assert-Gate @{ InfrastructureResult = 'failure' } $false 'an infrastructure job that failed while the flag is false'
	Assert-Gate @{ InfrastructureChange = $null } $false 'a missing infrastructure flag'
	Assert-Gate @{ InfrastructureChange = 'yes' } $false 'an invalid infrastructure flag'
	Assert-Gate (($pruned + $docsContext) + @{ InfrastructureChange = 'true'; InfrastructureResult = 'success' }) $false 'an infrastructure change in docs mode'
	Assert-Gate ((@{ General = 'skipped'; Public = 'skipped'; Internal = 'skipped'; Selective = 'success'; Compiled = 'success' } + $selectiveContext) + @{ InfrastructureChange = 'true'; InfrastructureResult = 'success' }) $false 'an infrastructure change in selective mode'
	Assert-Gate @{ General = 'failure' } $false 'a failed general job'
	Assert-Gate @{ Public = 'failure' } $false 'a failed public-function job'
	Assert-Gate @{ Lint = 'failure' } $false 'failed lint'
	Assert-Gate @{ ChangeResult = 'failure' } $false 'failed change detection'
	Assert-Gate @{ PlanHash = 'not-a-hash' } $false 'an invalid plan hash'
	Assert-Gate @{ SelectiveHash = ('B' * 64) } $false 'a mismatched plan hash'
	Assert-Gate @{ CompiledMode = 'docs' } $false 'a mismatched validation mode'

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
