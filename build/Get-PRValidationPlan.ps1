<#
.SYNOPSIS
    Derives the validation scope for a pull request.

.DESCRIPTION
    Derives module test, analyzer scan, selective test, compiled import, and
    infrastructure decisions from one change set. Help, comment, and layout-only
    edits that keep executable tokens skip compile and selective work.

.PARAMETER BaseSha
    The pull request base commit.

.PARAMETER HeadSha
    The pull request head commit.

.PARAMETER OutputPath
    Writes the plan as JSON for the workflow jobs that consume it.

.PARAMETER RepositoryPath
    The repository to inspect.

    Default: the parent of this script's directory.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $BaseSha,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $HeadSha,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $OutputPath,
	[string] $RepositoryPath = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$changeSet = & (Join-Path $PSScriptRoot 'Get-Ps1LintScope.ps1') -BaseSha $BaseSha -HeadSha $HeadSha -RepositoryPath $repository -ChangesOnly
$mergeBase = $changeSet.MergeBase
$entries = @($changeSet.Changes)

# The change-aware regression suites in build/ (run by
# build/Invoke-InfrastructureValidation.ps1) exercise this tooling. A path that
# can change their behavior must start the infrastructure job. Keep the set
# explicit: Test-PRValidationPlan.ps1 pins each pattern in both directions, so a
# new suite input is added here deliberately instead of by accident.
$infrastructurePattern = @(
	'^build/ps1-lint(/|$)'
	'^build/Get-[^/]+\.ps1$'
	'^build/Invoke-[^/]+\.ps1$'
	'^build/Test-[^/]+\.ps1$'
	'^build/Install-RequiredModules\.ps1$'
	'^build/Install-Prek\.ps1$'
	'^build/ModuleCacheRequirements\.json$'
	'^build/ToolCacheRequirements\.json$'
	'^prek\.toml$'
	'^\.github/workflows/validate\.yml$'
)

# The analyzer jobs run d365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1
# through d365bap.tools/tests/pester-PSScriptAnalyzer.ps1. Nothing else under
# tests/ reaches them, so a change to those two files is the only test change
# that needs the full scans.
$analyzerHarnessPath = @(
	'd365bap.tools/tests/general/PSScriptAnalyzer.Tests.ps1'
	'd365bap.tools/tests/pester-PSScriptAnalyzer.ps1'
)

# A module test change runs the General job, which excludes the analyzer
# harness. Behavior tests run as an optional step in the compiled-import job
# only when these paths change (not on every compiled-import PR).
$behaviorTestPattern = '^d365bap\.tools/tests/behavior/'
$behaviorSourcePath = @(
	'd365bap.tools/functions/Get-PpacFinOpsAsset.ps1'
	'd365bap.tools/functions/Get-PpacFinOpsVersion.ps1'
	'd365bap.tools/functions/Get-PpacFinOpsBuild.ps1'
)

# A formatting-only change keeps every token and line-break layout. An
# executable-unchanged change allows comment/help edits and layout moves
# (including backtick continuations) when Kind|Text tokens still match. Both
# skip module tests, analyzer scans, selective tests, and compiled-import.
$modulePowerShellPattern = '^d365bap\.tools/.+\.(ps1|psm1|psd1)$'

function Test-Documentation([string] $Path) {
	if ([string]::IsNullOrEmpty($Path)) { $false; return }
	if ([IO.Path]::GetFileName($Path) -ieq 'AGENTS.md') { $false; return }
	$Path -ieq 'README.md' -or
	$Path -ieq 'd365bap.tools/readme.md' -or
	$Path -ieq 'd365bap.tools/changelog.md' -or
	$Path -match '^(docs|learning)/.+\.md$' -or
	$Path -match '^wiki/[^/]+\.md$'
}

function Get-ChangedText([string] $Revision, [string] $Path) {
	$start = [System.Diagnostics.ProcessStartInfo]::new()
	$start.FileName = 'git'
	$start.WorkingDirectory = $repository
	$start.UseShellExecute = $false
	$start.RedirectStandardOutput = $true
	$start.RedirectStandardError = $true
	foreach ($itemArgument in @('show', "${Revision}:$Path")) { $null = $start.ArgumentList.Add($itemArgument) }
	$process = [System.Diagnostics.Process]::Start($start)
	try {
		$errorTask = $process.StandardError.ReadToEndAsync()
		$bytes = [System.IO.MemoryStream]::new()
		try {
			$process.StandardOutput.BaseStream.CopyTo($bytes)
			$process.WaitForExit()
			$null = $errorTask.GetAwaiter().GetResult()
			if ($process.ExitCode -ne 0) { return }
			[Text.Encoding]::UTF8.GetString($bytes.ToArray()).TrimStart([char]0xFEFF)
		}
		finally { $bytes.Dispose() }
	}
	finally { $process.Dispose() }
}

function Get-TokenSignature([string] $Text) {
	if ([string]::IsNullOrEmpty($Text)) { return }
	# Line endings are the lint hook's business: a checkout may use CRLF while
	# the blob uses LF, and a multi-line comment or here-string token keeps the
	# endings inside its text. Normalize before comparing tokens.
	$normalizedText = $Text.Replace("`r`n", "`n")
	$colTokens = $null
	$parseErrors = $null
	$null = [Management.Automation.Language.Parser]::ParseInput($normalizedText, [ref]$colTokens, [ref]$parseErrors)
	if ($null -eq $colTokens -or @($parseErrors).Count -gt 0) { return }
	$colSignature = [System.Collections.Generic.List[string]]::new()
	$previousEndLine = 0
	foreach ($itemToken in $colTokens) {
		# Newline tokens carry no text of their own; the line-break flag below
		# already records where one sits, and a blank line is inert.
		if ($itemToken.Kind -eq 'NewLine') { continue }
		# The line-break flag keeps a moved statement a real change. Tokens keep
		# the text of strings, here-strings, and comments, so editing any of
		# them disqualifies the file as well.
		$startsLine = if ($itemToken.Extent.StartLineNumber -ne $previousEndLine) { '1' } else { '0' }
		$colSignature.Add("$startsLine|$($itemToken.Kind)|$($itemToken.Text)")
		$previousEndLine = $itemToken.Extent.EndLineNumber
	}
	$colSignature -join "`n"
}

function Get-ExecutableTokenSignature([string] $Text) {
	if ([string]::IsNullOrEmpty($Text)) { return }
	$normalizedText = $Text.Replace("`r`n", "`n")
	$colTokens = $null
	$parseErrors = $null
	$null = [Management.Automation.Language.Parser]::ParseInput($normalizedText, [ref]$colTokens, [ref]$parseErrors)
	if ($null -eq $colTokens -or @($parseErrors).Count -gt 0) { return }
	$colSignature = [System.Collections.Generic.List[string]]::new()
	foreach ($itemToken in $colTokens) {
		if ($itemToken.Kind -in @('Comment', 'NewLine', 'LineContinuation', 'EndOfInput')) { continue }
		$colSignature.Add("$($itemToken.Kind)|$($itemToken.Text)")
	}
	$colSignature -join "`n"
}

function Test-FormattingOnlyChange($Entry) {
	if ($Entry.Status -cne 'M' -or $null -ne $Entry.OldPath) { $false; return }
	$path = $Entry.Path -replace '\\', '/'
	if ($path -notmatch $modulePowerShellPattern) { $false; return }
	$headPath = Join-Path $repository $path
	if (-not (Test-Path -LiteralPath $headPath -PathType Leaf)) { $false; return }
	$baseText = Get-ChangedText -Revision $mergeBase -Path $path
	if ([string]::IsNullOrEmpty($baseText)) { $false; return }
	$headText = [IO.File]::ReadAllText($headPath).TrimStart([char]0xFEFF)
	if ([string]::IsNullOrEmpty($headText) -or $baseText -ceq $headText) { $false; return }
	# Whitespace around a line continuation changes meaning, so a file that uses
	# one keeps the full module coverage.
	if ($baseText -match '(?m)`[ \t\r]*$' -or $headText -match '(?m)`[ \t\r]*$') { $false; return }
	$baseSignature = Get-TokenSignature -Text $baseText
	$headSignature = Get-TokenSignature -Text $headText
	if ([string]::IsNullOrEmpty($baseSignature) -or [string]::IsNullOrEmpty($headSignature)) { $false; return }
	$baseSignature -ceq $headSignature
}

function Test-ExecutableUnchangedChange($Entry) {
	if ($Entry.Status -cne 'M' -or $null -ne $Entry.OldPath) { $false; return }
	$path = $Entry.Path -replace '\\', '/'
	if ($path -notmatch $modulePowerShellPattern) { $false; return }
	$headPath = Join-Path $repository $path
	if (-not (Test-Path -LiteralPath $headPath -PathType Leaf)) { $false; return }
	$baseText = Get-ChangedText -Revision $mergeBase -Path $path
	if ([string]::IsNullOrEmpty($baseText)) { $false; return }
	$headText = [IO.File]::ReadAllText($headPath).TrimStart([char]0xFEFF)
	if ([string]::IsNullOrEmpty($headText) -or $baseText -ceq $headText) { $false; return }
	# A backtick must be the last character to continue a line. Whitespace after
	# it escapes that whitespace instead, so treat it as an executable change.
	if ($baseText -match '(?m)`[ \t]+$' -or $headText -match '(?m)`[ \t]+$') { $false; return }
	$baseSignature = Get-ExecutableTokenSignature -Text $baseText
	$headSignature = Get-ExecutableTokenSignature -Text $headText
	if ([string]::IsNullOrEmpty($baseSignature) -or [string]::IsNullOrEmpty($headSignature)) { $false; return }
	$baseSignature -ceq $headSignature
}

$colReasons = [System.Collections.Generic.List[string]]::new()
$colPublicPaths = [System.Collections.Generic.List[string]]::new()
$colInfrastructurePaths = [System.Collections.Generic.List[string]]::new()
$isModuleTests = $false
$isAnalyzerScans = $false
$isSelectiveTests = $false
$isCompiledImport = $false
$isBehaviorTests = $false
$fallback = $false
$formattingOnly = $true
$executableUnchanged = $true
$nonDocumentationCount = 0
if ($entries.Count -eq 0) {
	$fallback = $true
	$isModuleTests = $true
	$isAnalyzerScans = $true
	$colReasons.Add('No changed files were detected.')
}
foreach ($entry in $entries) {
	# Both sides of a rename count: moving tooling out of build/ still changes it.
	$path = $entry.Path -replace '\\', '/'
	$oldPath = if ([string]::IsNullOrEmpty($entry.OldPath)) { $null } else { $entry.OldPath -replace '\\', '/' }
	$pathInfrastructure = $false
	$oldInfrastructure = $false
	foreach ($candidate in @($path) + @($oldPath)) {
		if ([string]::IsNullOrEmpty($candidate)) { continue }
		foreach ($pattern in $infrastructurePattern) {
			if ($candidate -notmatch $pattern) { continue }
			$colInfrastructurePaths.Add($candidate)
			if ($candidate -ceq $path) { $pathInfrastructure = $true }
			if ($candidate -ceq $oldPath) { $oldInfrastructure = $true }
			break
		}
	}
	if ((Test-Documentation $entry.Path) -and ($null -eq $entry.OldPath -or (Test-Documentation $entry.OldPath))) { continue }
	$nonDocumentationCount++

	if ($formattingOnly) {
		if (-not (Test-FormattingOnlyChange $entry)) { $formattingOnly = $false }
	}
	if ($executableUnchanged) {
		if (-not (Test-ExecutableUnchangedChange $entry)) { $executableUnchanged = $false }
	}

	if ($pathInfrastructure) { continue }
	if ($oldInfrastructure) {
		# Moving tooling out of build/ leaves an unknown destination, so keep the
		# conservative fallback even though the flag is already set.
		$fallback = $true
		$isModuleTests = $true
		$isAnalyzerScans = $true
		$colReasons.Add("Infrastructure moved to an unknown path: $($entry.Status) $path")
		continue
	}
	if ($path -match '^d365bap\.tools/tests/') {
		if ($analyzerHarnessPath -contains $path) { $isAnalyzerScans = $true; continue }
		# Behavior suites run as an optional step on the compiled-import job.
		if ($path -match $behaviorTestPattern) {
			$isBehaviorTests = $true
			$isCompiledImport = $true
			continue
		}
		$isModuleTests = $true
		continue
	}
	if ($path -match '^d365bap\.tools/') {
		$isPublic = $entry.Status -in @('A', 'M') -and
		$null -eq $oldPath -and
		$path -match '^d365bap\.tools/functions/[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*\.ps1$' -and
		(Test-Path -LiteralPath (Join-Path $repository $path) -PathType Leaf)
		if ($isPublic) {
			$isSelectiveTests = $true
			$colPublicPaths.Add($path)
			if ($behaviorSourcePath -contains $path) { $isBehaviorTests = $true }
			continue
		}
		# Shared or deleted module code: the full module coverage stays until
		# dependency selection is proven.
		$isModuleTests = $true
		$isAnalyzerScans = $true
		continue
	}

	$fallback = $true
	$isModuleTests = $true
	$isAnalyzerScans = $true
	$colReasons.Add("Shared, unknown, deleted, or renamed path: $($entry.Status) $path")
}

$infrastructureChange = $entries.Count -eq 0 -or $colInfrastructurePaths.Count -gt 0

# Everything except a documentation-only change loads the module. The plan emits
# no other partial scope, which is the invariant the result gate enforces.
if ($fallback -or $isModuleTests -or $isAnalyzerScans -or $isSelectiveTests -or $infrastructureChange) {
	$isCompiledImport = $true
}

if ($formattingOnly -and -not $fallback -and $nonDocumentationCount -gt 0 -and -not $infrastructureChange) {
	$isModuleTests = $false
	$isAnalyzerScans = $false
	$isSelectiveTests = $false
	$isBehaviorTests = $false
	$isCompiledImport = $false
	$colPublicPaths.Clear()
	$colReasons.Add('Formatting-only change: the changed module files keep every token and line break.')
}

if ($executableUnchanged -and -not $fallback -and $nonDocumentationCount -gt 0 -and -not $infrastructureChange) {
	$isModuleTests = $false
	$isAnalyzerScans = $false
	$isSelectiveTests = $false
	$isBehaviorTests = $false
	$isCompiledImport = $false
	$colPublicPaths.Clear()
	$colReasons.Add('Executable-unchanged: comments, help, or layout differ; executable tokens match.')
}

$colScope = [System.Collections.Generic.List[string]]::new()
if ($isSelectiveTests) { $colScope.Add('selective') }
if ($isModuleTests) { $colScope.Add('module-tests') }
if ($isAnalyzerScans) { $colScope.Add('analyzer-scans') }
if ($isCompiledImport) { $colScope.Add('compiled-import') }
if ($infrastructureChange) { $colScope.Add('infrastructure') }
$scope = if ($colScope.Count -eq 0) { 'docs' } else { $colScope -join '+' }

# Compatibility alias for consumers that predate the split. The base-branch
# workflow rejects a plan without a valid Mode, so keep deriving one from the
# decisions: documentation stays docs, a targeted public-function change stays
# selective, and everything else keeps the former full label. A base job may run
# more work than the new scope; the flags below remain the decision source.
$mode = if ($scope -ceq 'docs') {
	'docs'
}
elseif ($isSelectiveTests -and -not $isModuleTests -and -not $isAnalyzerScans -and -not $infrastructureChange) {
	'selective'
}
else {
	'full'
}

$plan = [ordered]@{
	Mode                 = $mode
	Scope                = $scope
	ModuleTests          = $isModuleTests
	AnalyzerScans        = $isAnalyzerScans
	SelectiveTests       = $isSelectiveTests
	CompiledImport       = $isCompiledImport
	BehaviorTests        = $isBehaviorTests
	InfrastructureChange = $infrastructureChange
	InfrastructurePaths  = @($colInfrastructurePaths | Sort-Object -Unique)
	PublicPaths          = @($colPublicPaths | Sort-Object -Unique)
	Reasons              = @($colReasons)
	MergeBase            = $mergeBase
	HeadSha              = $HeadSha
}
$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Validation scope: $scope ($($entries.Count) changed file(s))."
Write-Host "Compatibility mode: $mode."
Write-Host "Module tests: $isModuleTests; analyzer scans: $isAnalyzerScans; selective tests: $isSelectiveTests; compiled import: $isCompiledImport; behavior tests: $isBehaviorTests; infrastructure: $infrastructureChange."
foreach ($reason in $colReasons) { Write-Host "  $reason" }
