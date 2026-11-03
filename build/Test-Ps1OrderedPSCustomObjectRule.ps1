<#
.SYNOPSIS
    Tests the ordered PSCustomObject lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a [pscustomobject] built from a
    hashtable literal goes through [ordered]. Ordered literals, parenthesised
    ordered literals, and variable children stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1OrderedPSCustomObjectDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('ordered-pscustomobject-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Ordered {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1OrderedPSCustomObjectDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-Ordered 'Unordered hashtable literal' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -Expected 1 @('PSUseOrderedPSCustomObject', '[ordered]')

Assert-Ordered 'Ordered conversion passes' @'
function Get-Fixture {
    $objResult = [pscustomobject][ordered]@{
        Name = 'fixture'
    }
    $objResult
}
'@

Assert-Ordered 'Parenthesised ordered conversion passes' @'
function Get-Fixture {
    $objResult = [pscustomobject]([ordered]@{
        Name = 'fixture'
    })
    $objResult
}
'@

Assert-Ordered 'Parenthesised hashtable literal' @'
function Get-Fixture {
    $objResult = [pscustomobject](@{
        Name = 'fixture'
    })
    $objResult
}
'@ -Expected 1

Assert-Ordered 'Double-parenthesised hashtable literal' @'
function Get-Fixture {
    $objResult = [pscustomobject]((@{
        Name = 'fixture'
    }))
    $objResult
}
'@ -Expected 1

Assert-Ordered 'Variable child' @'
function Get-Fixture {
    $hashSource = @{
        Name = 'fixture'
    }
    $objResult = [pscustomobject]$hashSource
    $objResult
}
'@

Assert-Ordered 'Hashtable cast bypass' '[pscustomobject][hashtable]@{ Name = 1 }' -Expected 1
Assert-Ordered 'Hashtable erases ordered proof' '[pscustomobject][hashtable][ordered]@{ Name = 1 }' -Expected 1
Assert-Ordered 'Parenthesised cast chain' '[PSCustomObject](([hashtable]([ordered]@{ Name = 1 })))' -Expected 1
Assert-Ordered 'Qualified ordered and parentheses' '[System.Management.Automation.PSCustomObject](([ordered]@{ Name = 1 }))'
Assert-Ordered 'Nonliteral cast chain' '[pscustomobject][hashtable]$source'
Assert-Ordered 'String and comment' @'
# [pscustomobject][hashtable]@{ Name = 1 }
$text = '[pscustomobject]@{ Name = 1 }'
'@
Assert-Ordered 'Nested cast objects' '[pscustomobject][hashtable]@{ Inner = [pscustomobject][hashtable]@{} }' -Expected 2

Assert-Ordered 'Full type name' @'
function Get-Fixture {
    $objResult = [System.Management.Automation.PSCustomObject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -Expected 1

Assert-Ordered 'Type name casing' @'
function Get-Fixture {
    $objResult = [PSCustomObject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -Expected 1

Assert-Ordered 'Nested unordered literals' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
        Inner = [pscustomobject]@{
            Value = 1
        }
    }
    $objResult
}
'@ -Expected 2

Assert-Ordered 'Other conversions are ignored' @'
function Get-Fixture {
    $hashResult = [hashtable]@{
        Name = 'fixture'
    }
    $hashResult
}
'@

Assert-Ordered 'Internal module code is checked' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -Directory 'd365bap.tools/internal/functions' -Expected 1

Assert-Ordered 'Build scripts are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -Directory 'build'

Assert-Ordered 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-Ordered 'Test files are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Ordered PSCustomObject rule checks passed: $script:caseCount cases."
