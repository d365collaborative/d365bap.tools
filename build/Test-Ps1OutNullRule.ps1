<#
.SYNOPSIS
    Tests the Out-Null discard lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that output is discarded with a $null
    assignment instead of Out-Null. Command strings, comments, here-strings,
    and files that shadow the command stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1OutNullDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('out-null-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-OutNull {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1OutNullDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
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

Assert-OutNull 'Other build scripts are exempt' @'
function Get-Fixture {
    Get-Thing | Out-Null
}
'@ -Directory 'build/scripts'

Assert-OutNull 'Tepp fixtures are exempt' @'
function Get-Fixture {
    Get-Thing | Out-Null
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-OutNull 'Test files are exempt' @'
function Get-Fixture {
    Get-Thing | Out-Null
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Out-Null rule checks passed: $script:caseCount cases."
