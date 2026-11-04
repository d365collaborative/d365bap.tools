<#
.SYNOPSIS
    Tests the empty line after continuation lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a statement which ends through a
    backtick line continuation is followed by an empty line before the next
    statement.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1EmptyLineAfterContinuationDiagnostic'
	)) {
	. $itemPath
}
. "$PSScriptRoot/ps1-lint/internal/Invoke-Ps1Analysis.ps1"
if (@(Get-Ps1DiagnosticRule | Where-Object { $_.Id -eq 'Get-Ps1EmptyLineAfterContinuationDiagnostic' }).Count -ne 1) {
	throw 'Get-Ps1EmptyLineAfterContinuationDiagnostic is not registered in Get-Ps1DiagnosticRule.'
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'empty-line-continuation-rule'
$script:caseCount = 0

function Assert-EmptyLineAfterContinuation {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1EmptyLineAfterContinuationDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-EmptyLineAfterContinuation 'Issue example' @'
function Get-Fixture {
    $objSecureToken = ConvertTo-SecureString -String 'x' -AsPlainText -Force
    $tokenValue = ConvertFrom-SecureString -AsPlainText `
        -SecureString $objSecureToken
    $apiVersion = $script:BapApiVersions.PowerPlatform
    $tokenValue
}
'@ -Expected 1 @('PSUseEmptyLineAfterContinuation', 'Add an empty line')

Assert-EmptyLineAfterContinuation 'Continuation before return' @'
function Get-Fixture {
    $envDetail = Get-Environment `
        -EnvironmentId $EnvironmentId
    return $envDetail
}
'@ -Expected 1

Assert-EmptyLineAfterContinuation 'Continuation before continue' @'
function Get-Fixture {
    foreach ($item in $colItems) {
        Add-Member -InputObject $item `
            -NotePropertyName Done -NotePropertyValue $true
        continue
    }
}
'@ -Expected 1

Assert-EmptyLineAfterContinuation 'Two continuation lines' @'
function Get-Fixture {
    Get-Thing -Name 'x' `
        -First 1 `
        -Last 2
    $result = 1
    $result
}
'@ -Expected 1

Assert-EmptyLineAfterContinuation 'Empty line present' @'
function Get-Fixture {
    $tokenValue = ConvertFrom-SecureString -AsPlainText `
        -SecureString $objSecureToken

    $apiVersion = $script:BapApiVersions.PowerPlatform
    $tokenValue
}
'@

Assert-EmptyLineAfterContinuation 'Comment after the continuation' @'
function Get-Fixture {
    $tokenValue = ConvertFrom-SecureString -AsPlainText `
        -SecureString $objSecureToken
    # next value
    $apiVersion = $script:BapApiVersions.PowerPlatform
    $tokenValue
}
'@

Assert-EmptyLineAfterContinuation 'Continuation ends the block' @'
function Get-Fixture {
    if ($true) {
        Get-Thing `
            -Name 'x'
    }
}
'@

Assert-EmptyLineAfterContinuation 'Continuation is the last statement' @'
function Get-Fixture {
    Get-Thing `
        -Name 'x'
}
'@

Assert-EmptyLineAfterContinuation 'Multi-line parentheses are not a continuation' @'
function Get-Fixture {
    $value = Get-Thing -InputObject (
        Get-Other -Name 'x'
    )
    $value
}
'@

Assert-EmptyLineAfterContinuation 'Nested continuation inside a block' @'
function Get-Fixture {
    if ($true) {
        $value = Get-Thing `
            -Name 'x'
    }
    return
}
'@

Assert-EmptyLineAfterContinuation 'Backtick inside a string is not a continuation' @'
function Get-Fixture {
    $text = 'a `
b'
    $text
}
'@

Assert-EmptyLineAfterContinuation 'Single-line statements' @'
function Get-Fixture {
    $value = Get-Thing -Name 'x'
    $value
}
'@

Assert-EmptyLineAfterContinuation 'Internal module code is checked' @'
function Get-Fixture {
    Get-Thing `
        -Name 'x'
    return
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'



Assert-EmptyLineAfterContinuation 'Test files are exempt' @'
function Get-Fixture {
    Get-Thing `
        -Name 'x'
    return
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Empty line after continuation rule checks passed: $script:caseCount cases."
