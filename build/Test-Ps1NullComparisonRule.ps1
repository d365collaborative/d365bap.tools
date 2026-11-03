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
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1NotEqualNullDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'null-comparison-rule'
$script:caseCount = 0

$hashSettings = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1AnalyzerSettings.psd1')
if ($hashSettings.HighSignalRule -notcontains 'PSPossibleIncorrectComparisonWithNull') {
	throw 'PSPossibleIncorrectComparisonWithNull must be in HighSignalRule.'
}

function Assert-NotEqualNull {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1NotEqualNullDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
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
