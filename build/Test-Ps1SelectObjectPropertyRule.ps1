<#
.SYNOPSIS
    Tests the explicit Select-Object property lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that Select-Object names its projection
    explicitly. Simple property lists and non-projection shapes stay allowed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ComplexArrayElementDiagnostic', 'Get-Ps1SelectObjectPropertyDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('select-object-property-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-SelectObjectProperty {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1SelectObjectPropertyDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-SelectObjectProperty 'Issue example' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1 @('PSUseExplicitSelectObjectProperty', '-Property')

Assert-SelectObjectProperty 'Single calculated property' @'
function Get-Fixture {
    $item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Calculated property after a simple name' @'
function Get-Fixture {
    $item | Select-Object Name, @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Calculated property before a trailing parameter' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } } -First 1
}
'@ -Expected 1

Assert-SelectObjectProperty 'Explicit Property parameter' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-SelectObjectProperty 'Explicit abbreviated Property parameter' @'
function Get-Fixture {
    $item | Select-Object -Prop @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-SelectObjectProperty 'Simple property list' @'
function Get-Fixture {
    $item | Select-Object Name, Id
}
'@

Assert-SelectObjectProperty 'Wildcard only' @'
function Get-Fixture {
    $item | Select-Object *
}
'@

Assert-SelectObjectProperty 'First only' @'
function Get-Fixture {
    $item | Select-Object -First 1
}
'@

Assert-SelectObjectProperty 'ExpandProperty only' @'
function Get-Fixture {
    $item | Select-Object -ExpandProperty Name
}
'@

Assert-SelectObjectProperty 'Splat is not resolved' @'
function Get-Fixture {
    $item | Select-Object @params
}
'@

Assert-SelectObjectProperty 'Hashtable in a string' @'
function Get-Fixture {
    $text = 'Select-Object *, @{ Name = ''Kind'' }'
    $text
}
'@

Assert-SelectObjectProperty 'Hashtable in a comment' @'
function Get-Fixture {
    # Select-Object *, @{ Name = 'Kind' }
    Get-Thing
}
'@

Assert-SelectObjectProperty 'Internal module code is checked' @'
function Get-Fixture {
    $item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-SelectObjectProperty 'Build scripts are exempt' @'
$item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
'@ -Directory 'build/scripts'

Assert-SelectObjectProperty 'Tepp fixtures are exempt' @'
$item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-SelectObjectProperty 'Test files are exempt' @'
$item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Select-Object property rule checks passed: $script:caseCount cases."
