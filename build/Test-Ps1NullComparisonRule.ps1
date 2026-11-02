<#
.SYNOPSIS
    Tests the null comparison lint rules.

.DESCRIPTION
    Checks the repository rule for not-equal tests against $null and the
    built-in rule that requires $null on the left. Also checks that the
    built-in rule is in the fatal set.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1NotEqualNullDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
Import-Module PSScriptAnalyzer -RequiredVersion '1.25.0' -ErrorAction Stop

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('null-comparison-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

$hashSettings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1AnalyzerSettings.psd1')
if ($hashSettings.HighSignalRule -notcontains 'PSPossibleIncorrectComparisonWithNull') {
	throw 'PSPossibleIncorrectComparisonWithNull must be in HighSignalRule.'
}

function Assert-NotEqualNull {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1NotEqualNullDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

function Assert-BuiltIn {
	param([string] $Label, [string] $Expression, [int] $Expected)
	$scriptText = "function Test-Fixture {`n    $Expression`n}"
	$colDiagnostics = @(Invoke-ScriptAnalyzer -ScriptDefinition $scriptText -IncludeRule 'PSPossibleIncorrectComparisonWithNull')
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count)"
	}
	$script:caseCount++
}

Assert-NotEqualNull 'Null on the left with not equal' @'
function Get-Fixture {
    if ($null -ne $x) { 'yes' }
}
'@ -Expected 1 @('PSAvoidNotEqualNull', '-Not ($null -eq')

Assert-NotEqualNull 'Null on the left with case-sensitive not equal' @'
function Get-Fixture {
    if ($null -cne $x) { 'yes' }
}
'@ -Expected 1

Assert-NotEqualNull 'Null on the left with explicit case-insensitive not equal' @'
function Get-Fixture {
    if ($null -ine $x) { 'yes' }
}
'@ -Expected 1

Assert-NotEqualNull 'Parenthesised null on the left' @'
function Get-Fixture {
    if (($null) -ne $x) { 'yes' }
}
'@ -Expected 1

Assert-NotEqualNull 'Not around a positive null test' @'
function Get-Fixture {
    if (-Not ($null -eq $x)) { 'yes' }
}
'@

Assert-NotEqualNull 'Positive null test' @'
function Get-Fixture {
    if ($null -eq $x) { 'yes' }
}
'@

Assert-NotEqualNull 'Case-sensitive positive null test' @'
function Get-Fixture {
    if ($null -ceq $x) { 'yes' }
}
'@

Assert-NotEqualNull 'Right-hand null is owned by the built-in rule' @'
function Get-Fixture {
    if ($x -ne $null) { 'yes' }
}
'@

Assert-NotEqualNull 'Other not-equal comparison' @'
function Get-Fixture {
    if ($x -ne $y) { 'yes' }
}
'@

Assert-NotEqualNull 'Simplified Where-Object' @'
function Get-Fixture {
    Get-Thing | Where-Object Name -ne $null
}
'@

Assert-NotEqualNull 'Internal module code is checked' @'
function Get-Fixture {
    if ($null -ne $x) { 'yes' }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-NotEqualNull 'Build scripts are exempt' @'
function Get-Fixture {
    if ($null -ne $x) { 'yes' }
}
'@ -Directory 'build'

Assert-NotEqualNull 'Tepp fixtures are exempt' @'
function Get-Fixture {
    if ($null -ne $x) { 'yes' }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-NotEqualNull 'Test files are exempt' @'
function Get-Fixture {
    if ($null -ne $x) { 'yes' }
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Assert-BuiltIn 'Right-hand equal' 'if ($x -eq $null) { }' 1
Assert-BuiltIn 'Right-hand not equal' 'if ($x -ne $null) { }' 1
Assert-BuiltIn 'Right-hand case-sensitive equal' 'if ($Value -ceq $null) { }' 1
Assert-BuiltIn 'Right-hand case-sensitive not equal' 'if ($Value -cne $null) { }' 1
Assert-BuiltIn 'Right-hand upper-case null' 'if ($Value -eq $NULL) { }' 1
Assert-BuiltIn 'Right-hand explicit case-insensitive not equal' 'if ($Value -ine $null) { }' 1
Assert-BuiltIn 'Left-hand equal' 'if ($null -eq $x) { }' 0
Assert-BuiltIn 'Left-hand not equal' 'if ($null -ne $x) { }' 0
Assert-BuiltIn 'Simplified Where-Object' 'Where-Object Name -ne $null' 0
Assert-BuiltIn 'Scriptblock Where-Object' 'Where-Object { $_.Name -eq $null }' 1

Write-Output "Null comparison rule checks passed: $script:caseCount cases."
