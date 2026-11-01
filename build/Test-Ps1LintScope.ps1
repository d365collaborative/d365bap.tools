[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-lint-scope-' + [guid]::NewGuid().ToString('N'))
$scopeScript = Join-Path $PSScriptRoot 'Get-Ps1LintScope.ps1'

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

function New-ScopeFile([string] $Repository, [string] $RelativePath, [string] $Content) {
	$path = Join-Path $Repository $RelativePath
	$parent = Split-Path $path -Parent
	if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
	Set-Content -LiteralPath $path -Value $Content -Encoding utf8
}

function Invoke-Scope([string] $Repository, [string] $Base, [string] $Head) {
	& $scopeScript -BaseSha $Base -HeadSha $Head -RepositoryPath $Repository
}

try {
	$null = New-Item -ItemType Directory -Path $root -Force
	Invoke-Git $root @('init') | Out-Null
	Invoke-Git $root @('config', 'user.email', 'scope@example.invalid') | Out-Null
	Invoke-Git $root @('config', 'user.name', 'Scope Test') | Out-Null

	New-ScopeFile $root 'd365bap.tools/functions/Get-Thing.ps1' @'
function Get-Thing {
	[OutputType('D365Bap.Tools.Thing')]
	param()

	Get-SourceThing | Select-PSFObject -TypeName 'D365Bap.Tools.Thing'
}
'@
	New-ScopeFile $root 'd365bap.tools/functions/Get-ThingCaller.ps1' @'
function Get-ThingCaller {
	param()

	Get-Thing
}
'@
	New-ScopeFile $root 'build/Run-Thing.ps1' "Get-Thing`n"
	New-ScopeFile $root 'd365bap.tools/functions/ps1-lint.json' "{}`n"
	New-ScopeFile $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml' @'
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
	New-ScopeFile $root 'build/ps1-lint/internal/Rule.ps1' "function Get-Rule { }`n"
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'base') | Out-Null
	$base = Invoke-Git $root @('rev-parse', 'HEAD')

	# A changed config rechecks its directory.
	New-ScopeFile $root 'd365bap.tools/functions/ps1-lint.json' "{`n  `"allowedParameterAliases`": []`n}`n"
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'config') | Out-Null
	$configHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $configHead
	Assert-Set $scope.DependencyFiles @('d365bap.tools/functions/Get-Thing.ps1', 'd365bap.tools/functions/Get-ThingCaller.ps1') 'Config scope'
	Assert-True (-not $scope.FullScan) 'A config change must not force a full scan.'

	# A changed format view rechecks functions that emit the type.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	New-ScopeFile $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml' @'
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
	Add-Content -LiteralPath (Join-Path $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml') -Value '<!-- changed -->'
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'format') | Out-Null
	$formatHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $formatHead
	Assert-Set $scope.DependencyFiles @('d365bap.tools/functions/Get-Thing.ps1') 'Format view scope'

	# A changed OutputType rechecks callers.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	New-ScopeFile $root 'd365bap.tools/functions/Get-Thing.ps1' @'
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
	Assert-Set $scope.DependencyFiles @('build/Run-Thing.ps1', 'd365bap.tools/functions/Get-ThingCaller.ps1') 'OutputType caller scope'

	# A rule change recommends a full scan and enumerates the module.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	Add-Content -LiteralPath (Join-Path $root 'build/ps1-lint/internal/Rule.ps1') -Value '# changed'
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'rule') | Out-Null
	$ruleHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $ruleHead
	Assert-True ($scope.FullScan) 'A rule change must recommend a full scan.'
	Assert-True ($scope.DependencyFiles -contains 'd365bap.tools/functions/Get-Thing.ps1') 'A rule change must include module files.'

	# Malformed format XML is reported instead of silently skipped.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	New-ScopeFile $root 'd365bap.tools/xml/formats/table/D365Bap.Tools.Thing.Table.Format.ps1xml' '<Configuration><ViewDefinitions>'
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'invalid format') | Out-Null
	$invalidHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $invalidHead
	Assert-True ($scope.InvalidFormatFiles.Count -eq 1) 'Malformed format XML must be reported.'

	# A clean changed script is linted but not treated as a dependency.
	Invoke-Git $root @('reset', '--hard', $base) | Out-Null
	New-ScopeFile $root 'd365bap.tools/functions/Get-Other.ps1' "function Get-Other { }`n"
	Invoke-Git $root @('add', '--all') | Out-Null
	Invoke-Git $root @('commit', '-m', 'clean') | Out-Null
	$cleanHead = Invoke-Git $root @('rev-parse', 'HEAD')
	$scope = Invoke-Scope $root $base $cleanHead
	Assert-True ($scope.Files -contains 'd365bap.tools/functions/Get-Other.ps1') 'A changed script must be in the lint scope.'
	Assert-True ($scope.DependencyFiles.Count -eq 0) 'A changed script without dependency changes must not be a dependency file.'

	Write-Host 'Lint dependency scope regression checks passed.'
}
finally {
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
