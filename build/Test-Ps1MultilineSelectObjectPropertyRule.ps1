<#
.SYNOPSIS
    Tests the multiline Select-Object property lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that more than one calculated property on
    a Select-Object property list starts on its own line. A single calculated
    property and a simple property list stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1MultilineSelectObjectPropertyDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('multiline-select-object-property-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-MultilineSelectObjectProperty {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1MultilineSelectObjectPropertyDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-MultilineSelectObjectProperty 'Calculated properties on one line' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1 @('PSUseMultilineSelectObjectProperty', 'own line')

Assert-MultilineSelectObjectProperty 'Second calculated property on the first line' @'
function Get-Fixture {
    $item | Select-Object -Property *,
        @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1

Assert-MultilineSelectObjectProperty 'Module-qualified command' @'
function Get-Fixture {
    $item | Microsoft.PowerShell.Utility\Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1

Assert-MultilineSelectObjectProperty 'One calculated property per line' @'
function Get-Fixture {
    $item | Select-Object -Property *,
        @{ Name = 'Kind'; Expression = { $kind } },
        @{ Name = 'Source'; Expression = { $source } }
}
'@

Assert-MultilineSelectObjectProperty 'One calculated property per line with a parameter after it' @'
function Get-Fixture {
    $item | Select-Object -Property *,
        @{ Name = 'Kind'; Expression = { $kind } },
        @{ Name = 'Source'; Expression = { $source } } -First 1
}
'@

Assert-MultilineSelectObjectProperty 'Single calculated property' @'
function Get-Fixture {
    $item | Select-Object -Property @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-MultilineSelectObjectProperty 'Simple property list' @'
function Get-Fixture {
    $item | Select-Object -Property Name, DisplayName
}
'@

Assert-MultilineSelectObjectProperty 'Splat' @'
function Get-Fixture {
    $hashSelect = @{
        Property = @(
            @{ Name = 'Kind'; Expression = { $kind } }
            @{ Name = 'Source'; Expression = { $source } }
        )
    }
    $item | Select-Object @hashSelect
}
'@

Assert-MultilineSelectObjectProperty 'Calculated property without -Property' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@

Assert-MultilineSelectObjectProperty 'Select-Object in a string' @'
function Get-Fixture {
    $text = "Select-Object -Property *, @{ Name = 'Kind'; Expression = { `$kind } }"
    $text
}
'@

Assert-MultilineSelectObjectProperty 'Where-Object is not Select-Object' @'
function Get-Fixture {
    $item | Where-Object { $_.Name }
}
'@

Assert-MultilineSelectObjectProperty 'Internal module code is checked' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-MultilineSelectObjectProperty 'Build scripts are exempt' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Directory 'build/scripts'

Assert-MultilineSelectObjectProperty 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-MultilineSelectObjectProperty 'Test files are exempt' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Multiline Select-Object property rule checks passed: $script:caseCount cases."
