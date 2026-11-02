[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-lint-scope-' + [guid]::NewGuid().ToString('N'))
$scopeScript = Join-Path $PSScriptRoot 'Get-Ps1LintScope.ps1'
$invokeScript = Join-Path $PSScriptRoot 'Invoke-Ps1LintScope.ps1'
$pwsh = (Get-Process -Id $PID).Path

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

function Invoke-Git([string] $Repository, [string[]] $Arguments) {
	$output = & git -C $Repository @Arguments 2>&1
	if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
	($output | Out-String).Trim()
}

function Write-ScopeFile([string] $Repository, [string] $RelativePath, [string] $Content) {
	$path = Join-Path $Repository $RelativePath
	$parent = Split-Path $path -Parent
	if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
	Set-Content -LiteralPath $path -Value $Content -Encoding utf8
}

function Invoke-Scope([string] $Repository, [string] $Base, [string] $Head) {
	& $scopeScript -BaseSha $Base -HeadSha $Head -RepositoryPath $Repository
}

function Invoke-LintScopeCli([string] $Repository, [string] $Base, [string] $Head) {
	& $pwsh -NoProfile -NonInteractive -File $invokeScript -BaseSha $Base -HeadSha $Head -RepositoryPath $Repository -RunAnalyzer 2>&1 | Out-String
}

try {
	$null = New-Item -ItemType Directory -Path $root -Force
	Invoke-Git $root @('init') | Out-Null
	Invoke-Git $root @('config', 'user.email', 'scope@example.invalid') | Out-Null
	Invoke-Git $root @('config', 'user.name', 'Scope Test') | Out-Null

	Write-ScopeFile $root 'd365bap.tools/functions/Get-Thing.ps1' @'
function Get-Thing {
	[OutputType('D365Bap.Tools.Thing')]
	param()

	Get-SourceThing | Select-PSFObject -TypeName 'D365Bap.Tools.Thing'
}
'@
	Write-ScopeFile $root 'd365bap.tools/functions/Get-ThingCaller.ps1' @'
function Get-ThingCaller {
	param()

	Get-Thing
}
'@
	# This file is never touched. Its lint violations must never become PR blockers.
	Write-ScopeFile $root 'd365bap.tools/functions/Get-Untouched.ps1' @'
function Get-Untouched {
	param()

	Write-Host 'untouched violation'
}
'@
	Write-ScopeFile $root 'build/Run-Thing.ps1' "Get-Thing`n"
	Write-ScopeFile $root 'd365bap.tools/functions/ps1-lint.json' "{}`n"
	Write-ScopeFile $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml' @'
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <ViewDefinitions>
    <View>
      <Name>D365Bap.Tools.Thing</Name>
      <ViewSelectedBy>
        <TypeName>D365Bap.Tools.Thing</TypeName>
      </ViewSelectedBy>
    </View>
  </ViewDefinitions>
</Configuration>
'@
	Write-ScopeFile $root 'build/ps1-lint/internal/Rule.ps1' "function Get-Rule { }`n"
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'base') | Out-Null
	$base = Invoke-Git $root @('rev-parse', 'HEAD')

	# A changed config rechecks its directory as report-only dependencies.
	Write-ScopeFile $root 'd365bap.tools/functions/ps1-lint.json' "{`n  `"allowedParameterAliases`": []`n}`n"
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'config') | Out-Null
	$configHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $configHead
	Assert-Set $scope.Files @() 'Config target scope'
	Assert-Set $scope.DependencyFiles @('d365bap.tools/functions/Get-Thing.ps1', 'd365bap.tools/functions/Get-ThingCaller.ps1', 'd365bap.tools/functions/Get-Untouched.ps1') 'Config dependency scope'
	Assert-True (-not $scope.FullScan) 'A config change must not force a full scan.'
	$output = Invoke-LintScopeCli $root $base $configHead
	Assert-True ($LASTEXITCODE -eq 0) "Untouched dependency violations must not fail the PR: $output"

	# A changed format view rechecks functions that emit the type.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Add-Content -LiteralPath (Join-Path $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml') -Value '<!-- changed -->'
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'format') | Out-Null
	$formatHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $formatHead
	Assert-Set $scope.Files @() 'Format view target scope'
	Assert-Set $scope.DependencyFiles @('d365bap.tools/functions/Get-Thing.ps1') 'Format view dependency scope'
	Assert-True ($scope.Metadata.FormatViews.Count -eq 1) 'Format XML metadata must be recorded once.'
	Assert-Set $scope.Metadata.FormatViews[0].Types @('D365Bap.Tools.Thing') 'Format XML metadata types'

	# A changed OutputType rechecks callers; the touched file stays the only target.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Write-ScopeFile $root 'd365bap.tools/functions/Get-Thing.ps1' @'
function Get-Thing {
	[OutputType('D365Bap.Tools.Other')]
	param()

	Get-SourceThing | Select-PSFObject -TypeName 'D365Bap.Tools.Thing'
}
'@
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'output type') | Out-Null
	$outputHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $outputHead
	Assert-Set $scope.Files @('d365bap.tools/functions/Get-Thing.ps1') 'OutputType target scope'
	Assert-Set $scope.DependencyFiles @('build/Run-Thing.ps1', 'd365bap.tools/functions/Get-ThingCaller.ps1') 'OutputType caller scope'
	Assert-True ($scope.Metadata.OutputTypeChanges.Count -eq 1) 'OutputType metadata must be recorded once.'

	# A rule change recommends a full scan and never widens the target set.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Add-Content -LiteralPath (Join-Path $root 'build/ps1-lint/internal/Rule.ps1') -Value '# changed'
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'rule') | Out-Null
	$ruleHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $ruleHead
	Assert-True ($scope.FullScan) 'A rule change must recommend a full scan.'
	Assert-Set $scope.Files @('build/ps1-lint/internal/Rule.ps1') 'Rule change target scope'
	Assert-Set $scope.DependencyFiles @() 'Rule change dependency scope'

	# Malformed format XML in a touched file is reported as a diagnostic.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Write-ScopeFile $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml' '<Configuration><ViewDefinitions>'
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'invalid format') | Out-Null
	$invalidHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $invalidHead
	Assert-True ($scope.Diagnostics.Count -eq 1) 'Malformed touched format XML must be reported.'
	Assert-True ($scope.Diagnostics[0].Kind -eq 'InvalidFormatXml' -and $scope.Diagnostics[0].Path -eq 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml') 'The diagnostic must identify the touched file.'

	# Deleting a format view rechecks functions from the base metadata without failing.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Invoke-Git $root @('rm', '-q', 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml') | Out-Null
	Invoke-Git $root @('commit', '-m', 'delete format') | Out-Null
	$deleteFormatHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $deleteFormatHead
	Assert-True ($scope.Diagnostics.Count -eq 0) 'A deleted format view must not be reported as invalid.'
	Assert-Set $scope.Files @() 'Deleted format target scope'
	Assert-Set $scope.DependencyFiles @('d365bap.tools/functions/Get-Thing.ps1') 'Deleted format dependency scope'
	Assert-Set $scope.Metadata.FormatViews[0].BaseTypes @('D365Bap.Tools.Thing') 'Deleted format base metadata'
	Assert-Set $scope.Metadata.FormatViews[0].HeadTypes @() 'Deleted format head metadata'

	# Renaming a format view keeps both the old and new metadata.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Invoke-Git $root @('mv', 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml', 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Renamed.Format.ps1xml') | Out-Null
	Invoke-Git $root @('commit', '-m', 'rename format') | Out-Null
	$renameFormatHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $renameFormatHead
	Assert-True ($scope.Diagnostics.Count -eq 0) 'A renamed format view must not be reported as invalid.'
	Assert-Set $scope.DependencyFiles @('d365bap.tools/functions/Get-Thing.ps1') 'Renamed format dependency scope'
	Assert-True ($scope.Metadata.FormatViews[0].OldPath -eq 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml') 'A renamed format view must keep the old path.'

	# A rename lints the new path only, and a deletion lints nothing.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Invoke-Git $root @('mv', 'build/Run-Thing.ps1', 'build/Run-ThingRenamed.ps1') | Out-Null
	Invoke-Git $root @('commit', '-m', 'rename script') | Out-Null
	$renameHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $renameHead
	Assert-Set $scope.Files @('build/Run-ThingRenamed.ps1') 'Renamed script target scope'
	$changeSet = & $scopeScript -BaseSha $base -HeadSha $renameHead -RepositoryPath $root -ChangesOnly
	Assert-True ($changeSet.MergeBase -eq $base) 'Changes-only output must include the merge base.'
	$colRenamed = @($changeSet.Changes | Where-Object Status -match '^R')
	Assert-True ($colRenamed.Count -eq 1 -and $colRenamed[0].OldPath -eq 'build/Run-Thing.ps1') 'Changes-only output must keep rename sources.'

	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Invoke-Git $root @('rm', '-q', 'build/Run-Thing.ps1') | Out-Null
	Invoke-Git $root @('commit', '-m', 'delete script') | Out-Null
	$deleteHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $deleteHead
	Assert-Set $scope.Files @() 'Deleted script target scope'
	Assert-Set $scope.DependencyFiles @() 'Deleted script dependency scope'

	# A clean changed script is the only target and has no dependencies.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Write-ScopeFile $root 'd365bap.tools/functions/Get-Other.ps1' "function Get-Other { }`n"
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'clean') | Out-Null
	$cleanHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $cleanHead
	Assert-Set $scope.Files @('d365bap.tools/functions/Get-Other.ps1') 'Changed script target scope'
	Assert-True (-not ($scope.Files -contains 'd365bap.tools/functions/Get-Untouched.ps1')) 'An untouched violating file must never be a target.'
	Assert-Set $scope.DependencyFiles @() 'A changed script without dependency changes must not be a dependency file.'

	Write-Host 'Lint dependency scope regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
