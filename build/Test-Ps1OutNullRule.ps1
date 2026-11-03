<#
.SYNOPSIS
    Tests the output discard lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that output is discarded with a > $null
    redirect instead of Out-Null or a $null assignment. Command strings,
    comments, here-strings, and files that shadow Out-Null stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1OutNullDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'out-null-rule'
$script:caseCount = 0

function Assert-OutNull {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1OutNullDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}
Assert-OutNull 'Pipeline discard' @'
function Get-Fixture {
    $parsed = $false
    [int]::TryParse('1', [ref]$parsed) | Out-Null
}
'@ -Expected 1 @('PSAvoidOutNull', '> $null')

Assert-OutNull 'InputObject discard' @'
function Get-Fixture {
    Out-Null -InputObject (Get-Thing)
}
'@ -Expected 1

Assert-OutNull 'Module-qualified command' @'
function Get-Fixture {
    Microsoft.PowerShell.Core\Out-Null (Get-Thing)
}
'@ -Expected 1

Assert-OutNull 'Case-insensitive command name' @'
function Get-Fixture {
    Get-Thing | out-null
}
'@ -Expected 1

Assert-OutNull 'Null redirect' @'
function Get-Fixture {
    Get-Thing > $null
}
'@

Assert-OutNull 'Null redirect with a method call' @'
function Get-Fixture {
    $parsed = $false
    [int]::TryParse('1', [ref]$parsed) > $null
}
'@

Assert-OutNull 'Command assigned to null' @'
function Get-Fixture {
    $null = Invoke-RestMethod -Method Post -Uri $uri
}
'@ -Expected 1 @('PSAvoidOutNull', 'assignment', 'Invoke-RestMethod')

Assert-OutNull 'Multi-line command assigned to null' @'
function Get-Fixture {
    $null = Invoke-RestMethod -Method Post `
        -Uri $uri `
        -Headers @{
        Authorization = "Bearer $tokenValue"
        Accept        = 'application/json'
    }
}
'@ -Expected 1 @('assignment', 'Invoke-RestMethod')

Assert-OutNull 'Parenthesized command assigned to null' @'
function Get-Fixture {
    $null = (Invoke-RestMethod -Method Post -Uri $uri)
}
'@ -Expected 1 @('Invoke-RestMethod')

Assert-OutNull 'Command assigned to null in a loop' @'
function Get-Fixture {
    foreach ($path in $paths) {
        $null = New-Item -ItemType Directory -Path $path -Force
    }
}
'@ -Expected 1 @('New-Item')

Assert-OutNull 'Method call assigned to null' @'
function Get-Fixture {
    $null = $list.Add($item)
}
'@ -Expected 1 @('expression')

Assert-OutNull 'Static method call assigned to null' @'
function Get-Fixture {
    $null = [Reflection.Assembly]::LoadFrom($path)
}
'@ -Expected 1

Assert-OutNull 'Property assigned to null' @'
function Get-Fixture {
    $null = $_.Exception.Message
}
'@ -Expected 1 @('<expression>')

Assert-OutNull 'Constant assigned to null' @'
function Get-Fixture {
    $null = 5
}
'@ -Expected 1

Assert-OutNull 'Array of variables assigned to null' @'
function Get-Fixture {
    $null = $commandName, $parameterName
}
'@ -Expected 1

Assert-OutNull 'Keyword statement assigned to null' @'
function Get-Fixture {
    $null = if ($true) { Get-Thing }
}
'@ -Expected 1 @('subexpression')

Assert-OutNull 'Keyword statement redirect' @'
function Get-Fixture {
    $(if ($true) { Get-Thing }) > $null
}
'@

Assert-OutNull 'Constant redirect' @'
function Get-Fixture {
    5 > $null
}
'@

Assert-OutNull 'Property redirect' @'
function Get-Fixture {
    $_.Exception.Message > $null
}
'@

Assert-OutNull 'Null assignment in a file that shadows Out-Null' @'
function Out-Null {
    param($InputObject)
}

function Get-Fixture {
    $null = Get-Thing
}
'@ -Expected 1

Assert-OutNull 'Null assignment with the case-insensitive name' @'
function Get-Fixture {
    $NULL = Get-Thing
}
'@ -Expected 1

Assert-OutNull 'Internal null assignment is checked' @'
function Get-Fixture {
    $null = Get-Thing
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'


Assert-OutNull 'Command name in a string' @'
function Get-Fixture {
    Get-Command Out-Null
}
'@

Assert-OutNull 'Out-Null in a comment' @'
function Get-Fixture {
    # Get-Thing | Out-Null
    Get-Thing
}
'@

$hereStringSource = @(
	'function Get-Fixture {'
	'    $example = @"'
	'    Get-Thing | Out-Null'
	'"@'
	'    $example'
	'}'
) -join "`n"
Assert-OutNull 'Out-Null in a here-string' $hereStringSource

Assert-OutNull 'Local function shadows Out-Null' @'
function Out-Null {
    param($InputObject)
}

function Get-Fixture {
    Get-Thing | Out-Null
}
'@

Assert-OutNull 'Local alias shadows Out-Null' @'
Set-Alias Out-Null Write-Output

function Get-Fixture {
    Get-Thing | Out-Null
}
'@

Assert-OutNull 'Lint tooling is checked' @'
function Get-Fixture {
    Get-Thing | Out-Null
}
'@ -Directory 'build/ps1-lint/internal' -Expected 1



Assert-OutNull 'Test files are exempt' @'
function Get-Fixture {
    Get-Thing | Out-Null
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Assert-OutNull 'Void casts' @'
function Get-Fixture {
    [void](Get-Thing)
    [System.Void]$list.Add($item)
}
'@ -Expected 2 @('void cast', '<expression> > $null')

Assert-OutNull 'Metadata and text' @'
function Get-Fixture {
    [OutputType([void])]
    param()
    # [void](Get-Thing)
    '[void](Get-Thing)'
}
'@

Assert-OutNull 'Qualified builtin despite shadow' @'
function Out-Null { param($InputObject) }
Get-Thing | Microsoft.PowerShell.Core\Out-Null
Get-Thing | Out-Null
Get-Thing | Custom.Module\Out-Null
'@ -Expected 1

$script:discardSideEffect = 0
$errors = @(& {
		& { $script:discardSideEffect++; Write-Output 'discarded'; Write-Error 'retained' -ErrorAction Continue } > $null
	} 2>&1)
if ($script:discardSideEffect -ne 1 -or $errors.Count -ne 1 -or $errors[0] -isnot [Management.Automation.ErrorRecord]) {
	throw 'Canonical discard must preserve side effects and error output.'
}

Write-Output "Out-Null rule checks passed: $script:caseCount cases."
