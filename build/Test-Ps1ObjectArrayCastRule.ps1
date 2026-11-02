<#
.SYNOPSIS
    Tests the object array cast lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a cast to [object[]] is reported.
    OutputType attributes, parameter declarations, and other element types stay
    clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ObjectArrayCastDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('object-array-cast-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-ObjectArrayCast {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1ObjectArrayCastDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-ObjectArrayCast 'Array cast over a response value' @'
function Get-Fixture {
    $response = Invoke-RestMethod -Uri 'https://example.invalid'
    $colResult = [object[]]@($response.value)
    $colResult
}
'@ -Expected 1 @('PSAvoidObjectArrayCast', 'already returns an array')

Assert-ObjectArrayCast 'Type-constrained assignment' @'
function Get-Fixture {
    [object[]] $colResult = @()
    $colResult
}
'@ -Expected 1

Assert-ObjectArrayCast 'Full type name' @'
function Get-Fixture {
    $colResult = [System.Object[]]@(Get-Thing)
    $colResult
}
'@ -Expected 1

Assert-ObjectArrayCast 'Plain object cast' @'
function Get-Fixture {
    $objResult = [object](Get-Thing)
    $objResult
}
'@

Assert-ObjectArrayCast 'OutputType attribute' @'
function Get-Fixture {
    [OutputType([object[]])]
    param()

    Get-Thing
}
'@

Assert-ObjectArrayCast 'OutputType attribute with the full name' @'
function Get-Fixture {
    [OutputType([System.Object[]])]
    param()

    Get-Thing
}
'@

Assert-ObjectArrayCast 'Parameter declaration' @'
function Get-Fixture {
    param (
        [object[]] $Policy
    )

    $Policy
}
'@

Assert-ObjectArrayCast 'Another element type' @'
function Get-Fixture {
    $colResult = [string[]]@('a', 'b')
    $colResult
}
'@

Assert-ObjectArrayCast 'Internal module code is checked' @'
function Get-Fixture {
    $colResult = [object[]]@(Get-Thing)
    $colResult
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-ObjectArrayCast 'Build scripts are exempt' @'
function Get-Fixture {
    $colResult = [object[]]@(Get-Thing)
    $colResult
}
'@ -Directory 'build'

Assert-ObjectArrayCast 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $colResult = [object[]]@(Get-Thing)
    $colResult
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-ObjectArrayCast 'Test files are exempt' @'
function Get-Fixture {
    $colResult = [object[]]@(Get-Thing)
    $colResult
}
'@ -Directory 'd365bap.tools/tests/functions'

Write-Output "Object array cast rule checks passed: $script:caseCount cases."
