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
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1OrderedPSCustomObjectDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'ordered-pscustomobject-rule'
$script:caseCount = 0

function Assert-Ordered {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1OrderedPSCustomObjectDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
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



Assert-Ordered 'Test files are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name = 'fixture'
    }
    $objResult
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Ordered PSCustomObject rule checks passed: $script:caseCount cases."
