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
. "$PSScriptRoot/ps1-lint/internal/Invoke-Ps1Analysis.ps1"
$analyzer = New-Ps1Analyzer
$ruleId = 'Get-Ps1EmptyLineAfterContinuationDiagnostic'
if (@(Get-Ps1DiagnosticRule | Where-Object { $_.Id -eq $ruleId }).Count -ne 1) {
	throw "$ruleId is not registered in Get-Ps1DiagnosticRule."
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('empty-line-continuation-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-EmptyLineAfterContinuation {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$result = Invoke-Ps1Analysis -Path $path -Analyzer $analyzer
	$colDiagnostics = @($result.Diagnostics | Where-Object RuleName -eq 'PSUseEmptyLineAfterContinuation')
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	foreach ($itemDiagnostic in $colDiagnostics) {
		if ($itemDiagnostic.Severity -ne 'Error') { throw "${Label}: expected Error severity, got $($itemDiagnostic.Severity)." }
	}
	if ($Expected -gt 0 -and -not $result.Failed) { throw "${Label}: the shared analyzer did not fail the bad fixture." }
	$script:caseCount++
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
