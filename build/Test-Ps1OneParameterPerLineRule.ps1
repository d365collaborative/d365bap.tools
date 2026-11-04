<#
.SYNOPSIS
    Tests the one-parameter-per-line lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a command with more than one
    parameter puts each parameter on its own line. The first parameter may stay
    on the command line or move to the first continuation line.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1OneParameterPerLineDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'one-parameter-per-line-rule'
$script:caseCount = 0

function Assert-OneParameterPerLine {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1OneParameterPerLineDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-OneParameterPerLine 'One parameter per line, first inline' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 `
        -Third 3
}
'@

Assert-OneParameterPerLine 'First parameter on the first continuation line' @'
function Get-Fixture {
    Get-Thing `
        -First 1 `
        -Second 2
}
'@

Assert-OneParameterPerLine 'Two parameters on a continuation line' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 -Third 3
}
'@ -Expected 1 @('PSUseOneParameterPerLine', 'own line')

Assert-OneParameterPerLine 'Two parameters on the command line' @'
function Get-Fixture {
    Get-Thing -First 1 -Second 2 `
        -Third 3
}
'@ -Expected 1

Assert-OneParameterPerLine 'Two parameters on the only continuation line' @'
function Get-Fixture {
    Get-Thing `
        -First 1 -Second 2
}
'@ -Expected 1

Assert-OneParameterPerLine 'Single-line command with several parameters' @'
function Get-Fixture {
    Get-Thing -First 1 -Second 2 -Third 3
}
'@ -Expected 1 @('own line')

Assert-OneParameterPerLine 'Single-line command with two parameters' @'
function Get-Fixture {
    Get-Thing -First 1 -Second 2
}
'@ -Expected 1

Assert-OneParameterPerLine 'Command with one parameter' @'
function Get-Fixture {
    Get-Thing -First 1
}
'@

Assert-OneParameterPerLine 'Format expression on a continuation line' @'
function Get-Fixture {
    $uri = 'https://example.invalid/{0}' `
        -f $Value
}
'@

Assert-OneParameterPerLine 'Nested command owns its continuation' @'
function Get-Fixture {
    Get-Thing -Filter {
        Get-Other -First 1 -Second 2 `
            -Third 3
    }
}
'@ -Expected 1

Assert-OneParameterPerLine 'Positional arguments are not parameters' @'
function Get-Fixture {
    Get-Thing 'first' `
        'second' `
        'third'
}
'@

Assert-OneParameterPerLine 'Internal module code is checked' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 -Third 3
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-OneParameterPerLine 'Lint tooling is checked' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 -Third 3
}
'@ -Expected 1 -Directory 'build/ps1-lint/internal'

Assert-OneParameterPerLine 'Other build scripts are exempt' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 -Third 3
}
'@ -Directory 'build/scripts'

Assert-OneParameterPerLine 'Tepp fixtures are exempt' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 -Third 3
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-OneParameterPerLine 'Test files are exempt' @'
function Get-Fixture {
    Get-Thing -First 1 `
        -Second 2 -Third 3
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "One parameter per line rule checks passed: $script:caseCount cases."
