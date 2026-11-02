[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-lint-correctness-' + [guid]::NewGuid().ToString('N'))
$hook = Join-Path $PSScriptRoot 'ps1-lint/psscriptanalyzer/Run.ps1'
$formatHook = Join-Path $PSScriptRoot 'ps1-lint/ps1-format/Run.ps1'
$readme = Join-Path $PSScriptRoot 'ps1-lint/README.md'
$pwsh = (Get-Process -Id $PID).Path

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Invoke-Hook([string] $Script, [string] $Path) {
	$output = @(& $pwsh -NoProfile -NonInteractive -File $Script $Path 2>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

try {
	$null = New-Item -ItemType Directory -Path $root -Force

	# A syntax error must fail even though PSScriptAnalyzer's Error filter does not see it.
	$syntax = Join-Path $root 'Broken.ps1'
	Set-Content -LiteralPath $syntax -Value 'function Broken {'
	$run = Invoke-Hook $hook $syntax
	Assert-True ($run.ExitCode -ne 0) 'A parse error must fail the analyzer hook.'
	Assert-True ($run.Output -match 'PSParseError') 'A parse error must be reported as PSParseError.'

	# A valid standalone script must still pass.
	$clean = Join-Path $root 'Clean.ps1'
	Set-Content -LiteralPath $clean -Value "Write-Output 'clean'"
	$run = Invoke-Hook $hook $clean
	Assert-True ($run.ExitCode -eq 0) "A clean script must pass the analyzer hook: $($run.Output)"

	# Module and manifest syntax is covered without applying function conventions.
	foreach ($itemExtension in @('psm1', 'psd1')) {
		$broken = Join-Path $root "Broken.$itemExtension"
		Set-Content -LiteralPath $broken -Value 'function Broken {'
		$run = Invoke-Hook $hook $broken
		Assert-True ($run.ExitCode -ne 0) "A broken .$itemExtension file must fail the analyzer hook."
		Assert-True ($run.Output -match 'PSParseError') "A broken .$itemExtension file must report PSParseError."
	}

	$manifest = Join-Path $root 'Valid.psd1'
	Set-Content -LiteralPath $manifest -Value "@{ ModuleVersion = '1.0.0' }"
	$run = Invoke-Hook $hook $manifest
	Assert-True ($run.ExitCode -eq 0) "A valid manifest must pass the analyzer hook: $($run.Output)"

	# A formatter failure with unchanged content must fail the format hook.
	$readOnly = Join-Path $root 'ReadOnly.ps1'
	[System.IO.File]::WriteAllText($readOnly, "Write-Output 'clean'`n", [System.Text.UTF8Encoding]::new($false))
	$before = (Get-FileHash -LiteralPath $readOnly -Algorithm SHA256).Hash
	(Get-Item -LiteralPath $readOnly).IsReadOnly = $true
	$run = Invoke-Hook $formatHook $readOnly
	(Get-Item -LiteralPath $readOnly).IsReadOnly = $false
	$after = (Get-FileHash -LiteralPath $readOnly -Algorithm SHA256).Hash
	Assert-True ($run.ExitCode -ne 0) 'A formatter failure must fail the format hook.'
	Assert-True ($run.Output -match 'formatting failed') 'A formatter failure must be reported.'
	Assert-True ($before -eq $after) 'The formatter failure proof must leave the file unchanged.'

	# Missing formatter settings are a failure, not a silent warning.
	. (Join-Path $PSScriptRoot 'ps1-lint/internal/Invoke-Ps1Format.ps1')
	$threw = $false
	try {
		Invoke-Ps1Format -Path $clean -SettingsPath (Join-Path $root 'missing.psd1')
	}
	catch {
		$threw = $true
		Assert-True ($_.Exception.Message -match 'Formatter settings not found') 'Missing formatter settings must report their cause.'
	}
	Assert-True $threw 'Missing formatter settings must throw.'

	# The hook dependency is pinned, not whatever happens to be installed.
	$hashSettings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1AnalyzerSettings.psd1')
	$objPin = [version] $hashSettings.PSScriptAnalyzerVersion
	Assert-True ("$objPin" -eq '1.25.0') 'The analyzer settings must pin PSScriptAnalyzer 1.25.0.'

	# CI and setup pins must match the import pin, or CI can install one version
	# while the hooks import another.
	$hashRequirements = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ModuleCacheRequirements.json') -Raw | ConvertFrom-Json
	foreach ($itemSet in @('lint', 'base')) {
		$colAnalyzer = @($hashRequirements.$itemSet | Where-Object Name -EQ 'PSScriptAnalyzer')
		Assert-True ($colAnalyzer.Count -eq 1 -and "$($colAnalyzer[0].Version)" -eq "$objPin") "The $itemSet module cache must pin PSScriptAnalyzer $objPin."
	}

	# Only the shared import may load the module. A direct Import-Module without
	# a version would pick the newest installed version again.
	foreach ($itemScript in @('Invoke-Ps1Format.ps1', 'Invoke-Ps1Analysis.ps1')) {
		$text = Get-Content -LiteralPath (Join-Path $PSScriptRoot "ps1-lint/internal/$itemScript") -Raw
		Assert-True ($text -match 'Import-Ps1Analyzer') "$itemScript must import PSScriptAnalyzer through the shared pin."
		Assert-True ($text -notmatch 'Import-Module\s+PSScriptAnalyzer') "$itemScript must not import PSScriptAnalyzer directly."
	}

	Import-Ps1Analyzer > $null
	Assert-True ("$((Get-Module -Name PSScriptAnalyzer).Version)" -eq "$objPin") 'Import-Ps1Analyzer must load the pinned version.'

	. (Join-Path $PSScriptRoot 'ps1-lint/internal/Ensure-PsScriptAnalyzer.ps1')
	Assert-True (Ensure-PsScriptAnalyzer) 'The setup hook default must make the pinned analyzer available.'
	$colInstalled = @(Get-Module -Name PSScriptAnalyzer -ListAvailable | Where-Object Version -EQ $objPin)
	Assert-True ($colInstalled.Count -gt 0) 'The pinned PSScriptAnalyzer version must be installed.'

	# A newer installed version must never win. The decoy fails when imported,
	# so formatting and analysis still passing proves the pin held.
	$decoyRoot = Join-Path $root 'decoy-modules/PSScriptAnalyzer/99.0.0'
	$null = New-Item -ItemType Directory -Path $decoyRoot -Force
	Set-Content -LiteralPath (Join-Path $decoyRoot 'PSScriptAnalyzer.psd1') -Value "@{ ModuleVersion = '99.0.0'; RootModule = 'PSScriptAnalyzer.psm1'; FunctionsToExport = @('Invoke-Formatter', 'Invoke-ScriptAnalyzer') }"
	Set-Content -LiteralPath (Join-Path $decoyRoot 'PSScriptAnalyzer.psm1') -Value "throw 'The decoy PSScriptAnalyzer 99.0.0 must never be imported.'"

	$formatSource = @'
$objValue=1
if ($null -eq $objValue) {
Write-Output 'pin'
}
'@
	$plain = Join-Path $root 'pin/Plain.ps1'
	$decoy = Join-Path $root 'pin/Decoy.ps1'
	foreach ($itemTarget in @($plain, $decoy)) {
		$null = New-Item -ItemType Directory -Path (Split-Path $itemTarget) -Force
		Set-Content -LiteralPath $itemTarget -Value $formatSource -Encoding utf8
	}

	$decoyModules = Join-Path $root 'decoy-modules'
	$runPlain = Invoke-Hook $formatHook $plain
	$analyzerPlain = Invoke-Hook $hook $clean
	$previousModulePath = $env:PSModulePath
	try {
		$env:PSModulePath = "$decoyModules$([IO.Path]::PathSeparator)$previousModulePath"
		$colDecoy = @(Get-Module -Name PSScriptAnalyzer -ListAvailable | Where-Object Version -EQ ([version] '99.0.0'))
		Assert-True ($colDecoy.Count -eq 1) 'The decoy analyzer version must be discoverable.'
		$runDecoy = Invoke-Hook $formatHook $decoy
		$analyzerDecoy = Invoke-Hook $hook $clean
	}
	finally {
		$env:PSModulePath = $previousModulePath
	}

	Assert-True ($runPlain.ExitCode -eq 1 -and $runDecoy.ExitCode -eq 1) 'The format hook must report the same unformatted fixture with a newer version installed.'
	$plainHash = (Get-FileHash -LiteralPath $plain -Algorithm SHA256).Hash
	$decoyHash = (Get-FileHash -LiteralPath $decoy -Algorithm SHA256).Hash
	Assert-True ($plainHash -ceq $decoyHash) 'Formatting must be byte-identical with a newer analyzer version installed.'
	Assert-True ($analyzerPlain.ExitCode -eq $analyzerDecoy.ExitCode -and $analyzerPlain.Output -ceq $analyzerDecoy.Output) 'Analysis must be identical with a newer analyzer version installed.'

	# The shared analysis helpers keep one scope table, cached node
	# collections, and one diagnostic shape. Their behavior is part of the
	# contract every rule relies on.
	foreach ($itemHelper in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis')) {
		. (Join-Path $PSScriptRoot "ps1-lint/internal/$itemHelper.ps1")
	}
	$helperRoot = Join-Path $root 'helpers'
	function New-HelperFixture {
		param([string] $RelativePath, [string] $Content)
		$path = Join-Path $helperRoot $RelativePath
		$null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
		[IO.File]::WriteAllText($path, $Content.Replace("`r`n", "`n"))
		$path
	}

	$moduleFunction = New-HelperFixture 'd365bap.tools/functions/Get-Thing.ps1' "function Get-Thing {`n`tGet-Date | Select-Object -First 1`n}`n"
	$moduleAnalysis = Get-Ps1Analysis -Path $moduleFunction
	Assert-True (Test-Ps1RuleScope -Analysis $moduleAnalysis -Scope 'ModuleSource') 'A public function file must be module source.'
	Assert-True (Test-Ps1RuleScope -Analysis $moduleAnalysis -Scope 'PublicFunction') 'A public function file must match the public-function scope.'
	Assert-True (Test-Ps1RuleScope -Analysis $moduleAnalysis -Scope 'Documentation') 'Comment linting covers module function files.'

	foreach ($itemCase in @(
			@{ Relative = 'd365bap.tools/functions/Get-Thing.Tests.ps1'; Scope = 'ModuleSource' }
			@{ Relative = 'd365bap.tools/internal/tepp/example.tepp.ps1'; Scope = 'ModuleSource' }
			@{ Relative = 'd365bap.tools/internal/tepp/assignment.ps1'; Scope = 'ModuleSource' }
			@{ Relative = 'd365bap.tools/tests/general/Help.ps1'; Scope = 'Documentation' }
			@{ Relative = 'build/Run-Thing.ps1'; Scope = 'ModuleOrLintTooling' }
		)) {
		$fixturePath = New-HelperFixture $itemCase.Relative "Write-Output 'fixture'`n"
		$fixtureAnalysis = Get-Ps1Analysis -Path $fixturePath
		Assert-True (-not (Test-Ps1RuleScope -Analysis $fixtureAnalysis -Scope $itemCase.Scope)) "$($itemCase.Relative) must not match the $($itemCase.Scope) scope."
	}

	$buildScript = New-HelperFixture 'build/Run-Thing.ps1' "Write-Output 'fixture'`n"
	$buildAnalysis = Get-Ps1Analysis -Path $buildScript
	Assert-True (Test-Ps1RuleScope -Analysis $buildAnalysis -Scope 'ModuleOrBuild') 'A build script must match the module-or-build scope.'
	Assert-True (-not (Test-Ps1RuleScope -Analysis $buildAnalysis -Scope 'ModuleSource')) 'A build script is not module source.'

	$lintTooling = New-HelperFixture 'build/ps1-lint/internal/Test-Thing.ps1' "Write-Output 'fixture'`n"
	$lintAnalysis = Get-Ps1Analysis -Path $lintTooling
	Assert-True (Test-Ps1RuleScope -Analysis $lintAnalysis -Scope 'ModuleOrLintTooling') 'Lint tooling must match the lint-tooling scope.'

	$outsideScript = New-HelperFixture 'scripts/Run-Thing.ps1' "Write-Output 'fixture'`n"
	$outsideAnalysis = Get-Ps1Analysis -Path $outsideScript
	Assert-True (Test-Ps1RuleScope -Analysis $outsideAnalysis -Scope 'Documentation') 'A script outside the module may use ordinary comments.'
	Assert-True (-not (Test-Ps1RuleScope -Analysis $outsideAnalysis -Scope 'ModuleSource')) 'A script outside the module is not module source.'

	# Node collections are cached once per type and search root.
	$colCommands = @(Get-Ps1AstNode -Analysis $moduleAnalysis -Type CommandAst)
	Assert-True ($colCommands.Count -eq 2) "The module fixture must contain two commands, found $($colCommands.Count)."
	$cacheKey = $moduleAnalysis.Ast
	Assert-True ($moduleAnalysis.Nodes[$cacheKey].ContainsKey('CommandAst')) 'The first node collection must be cached.'
	$cachedBefore = $moduleAnalysis.Nodes[$cacheKey].Count
	$null = @(Get-Ps1AstNode -Analysis $moduleAnalysis -Type CommandAst)
	Assert-True ($moduleAnalysis.Nodes[$cacheKey].Count -eq $cachedBefore) 'A repeated node collection must reuse the cached nodes.'

	$colPipes = @(Get-Ps1TokenNode -Analysis $moduleAnalysis -Kind Pipe)
	Assert-True ($colPipes.Count -eq 1) "The module fixture must contain one pipe token, found $($colPipes.Count)."
	Assert-True ($moduleAnalysis.TokenCache.ContainsKey('Pipe')) 'The first token collection must be cached.'

	$diagnostic = New-Ps1Diagnostic -Path $moduleFunction -Rule 'PSTestRule' -Message 'message' -Extent $moduleAnalysis.Ast.Extent
	Assert-True ($diagnostic.RuleName -eq 'PSTestRule' -and $diagnostic.Severity -eq 'Error') 'A diagnostic must keep its rule name and Error severity.'
	Assert-True ($diagnostic.ScriptName -eq 'Get-Thing.ps1') 'A diagnostic must report the file name without its directory.'
	Assert-True ($diagnostic.Line -eq 1 -and $diagnostic.Column -eq 1) 'A diagnostic must take its position from the extent.'
	$positional = New-Ps1Diagnostic -Path $moduleFunction -Rule 'PSTestRule' -Message 'message' -Line 4 -Column 2
	Assert-True ($positional.Line -eq 4 -and $positional.Column -eq 2) 'A diagnostic must take an explicit line and column.'
	$unpositioned = New-Ps1Diagnostic -Path $moduleFunction -Rule 'PSTestRule' -Message 'message'
	Assert-True ($null -eq $unpositioned.Line -and $null -eq $unpositioned.Column) 'A diagnostic without a position must keep null line and column.'

	# Repository metadata is one index per worker, shared by every rule. The
	# build counter proves the scan runs once, and a fresh worker proves a
	# later run sees files edited after the first run.
	. (Join-Path $PSScriptRoot 'ps1-lint/internal/Invoke-Ps1Analysis.ps1')

	# A built-in-only scan must keep only what the built-in analyzer and the
	# failure policy read. Comment groups and help sections exist for
	# repository rules and parse the file once per comment block, so
	# -SkipCustomRules must not build them.
	$builtInFixture = New-HelperFixture 'd365bap.tools/functions/Get-SkipFixture.ps1' @'
function Get-SkipFixture {
	<#
	.SYNOPSIS
		Fixture help.
	#>
	[CmdletBinding()]
	param(
		[string] $Name = 'x'
	)

	Write-Host $Name
}
'@
	$fullAnalysis = Get-Ps1Analysis -Path $builtInFixture
	Assert-True (@($fullAnalysis.CommentGroups).Count -eq 1) 'A full analysis must build comment groups for the fixture.'
	Assert-True (@($fullAnalysis.HelpSections).Count -eq 1) 'A full analysis must build help sections for the fixture.'

	$builtInAnalysis = Get-Ps1Analysis -Path $builtInFixture -SkipCustomRules
	Assert-True (-not $builtInAnalysis.ContainsKey('CommentGroups')) 'A built-in-only analysis must not build comment groups.'
	Assert-True (-not $builtInAnalysis.ContainsKey('HelpSections')) 'A built-in-only analysis must not build help sections.'
	Assert-True ($null -ne $builtInAnalysis.Ast.Extent) 'A built-in-only analysis must still parse the file.'

	# The entry point must ask for that mode, and a full scan must not.
	$builtInGet = @(Get-Command -Name Get-Ps1Analysis -CommandType Function)[0].ScriptBlock
	$script:analysisCall = [System.Collections.Generic.List[object]]::new()
	function Get-Ps1Analysis {
		param(
			[string] $Path,
			[AllowEmptyString()]
			[string] $Content,
			[switch] $SkipCustomRules
		)

		$script:analysisCall.Add([pscustomobject]@{ Path = $Path; SkipCustomRules = [bool] $SkipCustomRules })
		$hashParameter = @{ Path = $Path; SkipCustomRules = [bool] $SkipCustomRules }
		if ($PSBoundParameters.ContainsKey('Content')) { $hashParameter.Content = $Content }
		& $builtInGet @hashParameter
	}

	$skipAnalyzer = New-Ps1Analyzer
	$null = Invoke-Ps1Analysis -Path $builtInFixture -Analyzer $skipAnalyzer -SkipCustomRules
	Assert-True ($script:analysisCall.Count -eq 1 -and $script:analysisCall[0].SkipCustomRules) 'A built-in-only scan must build the analysis in built-in-only mode.'
	$script:analysisCall.Clear()
	$null = Invoke-Ps1Analysis -Path $builtInFixture -Analyzer $skipAnalyzer
	Assert-True ($script:analysisCall.Count -eq 1 -and -not $script:analysisCall[0].SkipCustomRules) 'A full scan must still build the comment groups and help sections.'

	# Diagnostics and the failure policy must not move. The built-in analyzer
	# with the shared settings stays the only diagnostic source, module
	# warnings stay fatal, the default gate stays warning-tolerant, and the
	# high-signal rules still fail a file the default severity would pass.
	$builtInResult = Invoke-Ps1Analysis -Path $builtInFixture -Analyzer $skipAnalyzer -SkipCustomRules
	$colBuiltInExpected = @(Invoke-ScriptAnalyzer -Path $builtInFixture `
			-Severity $skipAnalyzer.Settings.Severity `
			-ExcludeRule $skipAnalyzer.Settings.ExcludeRule `
			-ErrorAction Stop)
	$colExpectedLine = @($colBuiltInExpected | ForEach-Object {
			"$($_.RuleName)|$($_.Severity)|$($_.ScriptName)|$($_.Line)|$($_.Column)|$($_.Message)"
		} | Sort-Object)
	$colActualLine = @($builtInResult.Diagnostics | ForEach-Object {
			"$($_.RuleName)|$($_.Severity)|$($_.ScriptName)|$($_.Line)|$($_.Column)|$($_.Message)"
		} | Sort-Object)
	Assert-True ($colBuiltInExpected.Count -gt 0) 'The fixture must report at least one built-in diagnostic.'
	Assert-True (($colExpectedLine -join "`n") -ceq ($colActualLine -join "`n")) 'A built-in-only scan must report exactly the built-in analyzer diagnostics.'
	Assert-True $builtInResult.Failed 'A warning in a module function file is still fatal for a built-in-only scan.'

	$brokenFixture = New-HelperFixture 'build/Broken-Skip.ps1' "function Broken {`n"
	$parseResult = Invoke-Ps1Analysis -Path $brokenFixture -Analyzer $skipAnalyzer -SkipCustomRules
	$colParse = @($parseResult.Diagnostics)
	Assert-True ($colParse.Count -eq 1 -and $colParse[0].RuleName -eq 'PSParseError') 'A built-in-only scan must still report parse errors.'
	Assert-True $parseResult.Failed 'A parse error must still fail a built-in-only scan.'

	$warningFixture = New-HelperFixture 'build/Write-Skip.ps1' "Write-Host 'probe'`n"
	$warningResult = Invoke-Ps1Analysis -Path $warningFixture -Analyzer $skipAnalyzer -SkipCustomRules
	Assert-True (-not $warningResult.Failed) 'A warning outside a module function file must stay below the default gate.'

	$highSignalFixture = New-HelperFixture 'build/Start-Skip.ps1' "function Start-SkipThing {`n`ttry { 'x' }`n`tcatch {}`n}`n"
	$highSignalResult = Invoke-Ps1Analysis -Path $highSignalFixture -Analyzer $skipAnalyzer -SkipCustomRules
	Assert-True (@($highSignalResult.Diagnostics | Where-Object RuleName -eq 'PSAvoidUsingEmptyCatchBlock').Count -eq 1) 'The high-signal warning must still be reported for a built-in-only scan.'
	Assert-True $highSignalResult.Failed 'The high-signal rule must still fail a built-in-only scan.'

	# The formatted-text path must stay equivalent when custom rules are
	# skipped, so the combined batch hook cannot drift from the path scan.
	$contentResult = Invoke-Ps1Analysis -Path $highSignalFixture `
		-Analyzer $skipAnalyzer `
		-ContentByPath @{ $highSignalFixture = (Get-Content -LiteralPath $highSignalFixture -Raw) } `
		-SkipCustomRules
	$colContentLine = @($contentResult.Diagnostics | ForEach-Object {
			"$($_.RuleName)|$($_.Severity)|$($_.ScriptName)|$($_.Line)|$($_.Column)|$($_.Message)"
		} | Sort-Object)
	$colHighSignalLine = @($highSignalResult.Diagnostics | ForEach-Object {
			"$($_.RuleName)|$($_.Severity)|$($_.ScriptName)|$($_.Line)|$($_.Column)|$($_.Message)"
		} | Sort-Object)
	Assert-True (($colContentLine -join "`n") -ceq ($colHighSignalLine -join "`n")) 'A built-in-only scan of formatted text must report the same diagnostics as the path scan.'
	Assert-True ($contentResult.Failed -eq $highSignalResult.Failed) 'A built-in-only scan of formatted text must keep the same failure decision.'

	$indexRoot = Join-Path $root 'repository-index'
	$indexModule = Join-Path $indexRoot 'd365bap.tools'
	$indexCaller = Join-Path $indexModule 'functions/Get-IndexCaller.ps1'
	$null = New-Item -ItemType Directory -Path (Split-Path $indexCaller -Parent) -Force
	[IO.File]::WriteAllText($indexCaller, @'
function Get-IndexCaller {
	param()

	Get-IndexTarget @PSBoundParameters
}
'@)

	$indexKey = ($indexModule -replace '\\', '/').ToLowerInvariant()
	$indexAnalyzer = New-Ps1Analyzer
	$beforeTarget = Invoke-Ps1Analysis -Path $indexCaller -Analyzer $indexAnalyzer
	Assert-True (@($beforeTarget.Diagnostics | Where-Object RuleName -eq 'PSAvoidSplattingForModuleCommands').Count -eq 0) 'The splatting rule must not report a command that the module does not define.'
	Assert-True ($indexAnalyzer.Worker.RepositoryIndexBuilds[$indexKey] -eq 1) 'A worker must build the repository index once for the first module file.'

	$indexTarget = Join-Path $indexModule 'internal/functions/Get-IndexTarget.ps1'
	$null = New-Item -ItemType Directory -Path (Split-Path $indexTarget -Parent) -Force
	[IO.File]::WriteAllText($indexTarget, @'
function Get-IndexTarget {
	param([string] $Name)

	$Name
}
'@)

	$null = Invoke-Ps1Analysis -Path $indexCaller -Analyzer $indexAnalyzer
	$null = Invoke-Ps1Analysis -Path $indexTarget -Analyzer $indexAnalyzer
	Assert-True ($indexAnalyzer.Worker.RepositoryIndexBuilds[$indexKey] -eq 1) 'A worker must reuse its repository index for later files and rules.'

	$freshAnalyzer = New-Ps1Analyzer
	$afterTarget = Invoke-Ps1Analysis -Path $indexCaller -Analyzer $freshAnalyzer
	$colSplat = @($afterTarget.Diagnostics | Where-Object RuleName -eq 'PSAvoidSplattingForModuleCommands')
	Assert-True ($colSplat.Count -eq 1) "A fresh worker must see the edited module and report one splat, got $($colSplat.Count)."
	Assert-True ($colSplat[0].Message.Contains('Get-IndexTarget')) 'The splat diagnostic must name the command added after the first run.'
	Assert-True ($freshAnalyzer.Worker.RepositoryIndexBuilds[$indexKey] -eq 1) 'A fresh worker must build the repository index exactly once.'

	# A checkout folder named d365bap.tools above the module is not a module
	# root, so a build script must not scan it as repository metadata.
	$enclosingScript = Join-Path $root 'enclosing/d365bap.tools/build/Run-Thing.ps1'
	$null = New-Item -ItemType Directory -Path (Split-Path $enclosingScript -Parent) -Force
	[IO.File]::WriteAllText($enclosingScript, "Write-Output 'fixture'`n")
	$scopeAnalyzer = New-Ps1Analyzer
	$null = Invoke-Ps1Analysis -Path $enclosingScript -Analyzer $scopeAnalyzer
	Assert-True ($scopeAnalyzer.Worker.RepositoryIndexBuilds.Count -eq 0) 'A build script must not build an index for an enclosing checkout folder.'

	# The documented semantics must match the rule messages.
	$readmeText = Get-Content -LiteralPath $readme -Raw
	Assert-True ($readmeText -match 'already rejects null and empty values') 'README must describe mandatory string binding accurately.'
	Assert-True ($readmeText -match 'emits one null item into the pipeline') 'README must describe the return $null difference accurately.'
	$contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Get-Ps1ParameterContractDiagnostic.ps1') -Raw
	Assert-True ($contract -match 'state the non-empty contract explicitly') 'The parameter contract message must describe the convention.'
	$returnRule = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Get-Ps1ReturnValueDiagnostic.ps1') -Raw
	Assert-True ($returnRule -match 'emit \$null explicitly') 'The return-value message must preserve the pipeline distinction.'

	Write-Host 'Lint correctness regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
