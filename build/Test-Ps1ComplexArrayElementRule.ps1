<#
.SYNOPSIS
    Tests the complex array element lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a hashtable or scriptblock array
    element starts on its own line, while simple strings and a single complex
    element stay allowed on one line.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ComplexArrayElementDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'complex-array-element-rule'
$script:caseCount = 0

function Assert-ComplexArrayElement {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ComplexArrayElementDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-ComplexArrayElement 'Issue example' @'
function Get-Fixture {
    $colPolicies = @($colPolicies | Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, @{ Expression = { $_.name } }, @{ Expression = { $_.id } })
    $colPolicies
}
'@ -Expected 1 @('PSUseOneComplexArrayElementPerLine', 'own line')

Assert-ComplexArrayElement 'Select-Object property list' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1

Assert-ComplexArrayElement 'Scriptblock array' @'
function Get-Fixture {
    $grouped = $colItems | Group-Object { $_.Tenant.Id }, { $_.Account.Id }
    $grouped
}
'@ -Expected 1

Assert-ComplexArrayElement 'Crowded assignment array' @'
function Get-Fixture {
    $colSort = @(@{ Expression = { -not $_.IsEffective } }, @{ Expression = { $_.name } })
    $colSort
}
'@ -Expected 1

Assert-ComplexArrayElement 'Mixed simple and complex elements' @'
function Get-Fixture {
    $colPolicies = @($colPolicies | Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, 'name', @{ Expression = { $_.id } })
    $colPolicies
}
'@ -Expected 1

Assert-ComplexArrayElement 'PSCustomObject casts' @'
function Get-Fixture {
    $colRows = @([pscustomobject]@{ Name = 'a' }, [pscustomobject]@{ Name = 'b' })
    $colRows
}
'@ -Expected 1

Assert-ComplexArrayElement 'Trailing comma split' @'
function Get-Fixture {
    $colPolicies = @($colPolicies |
        Sort-Object -Property @{ Expression = { -not $_.IsEffective } },
        @{ Expression = { $_.name } },
        @{ Expression = { $_.id } })
    $colPolicies
}
'@

Assert-ComplexArrayElement 'Pre-built array' @'
function Get-Fixture {
    $colSort = @(
        @{ Expression = { -not $_.IsEffective } }
        @{ Expression = { $_.name } }
        @{ Expression = { $_.id } }
    )
    $colPolicies = @($colPolicies | Sort-Object -Property $colSort)
    $colPolicies
}
'@

Assert-ComplexArrayElement 'Simplified sort keys' @'
function Get-Fixture {
    $colPolicies = @($colPolicies |
        Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, 'name', 'id')
    $colPolicies
}
'@

Assert-ComplexArrayElement 'Simple string list' @'
function Get-Fixture {
    Get-Thing -Property 'a', 'b', 'c'
}
'@

Assert-ComplexArrayElement 'Single complex element' @'
function Get-Fixture {
    $item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-ComplexArrayElement 'Separate lines in an assignment' @'
function Get-Fixture {
    $colSort = @(
        @{ Expression = { -not $_.IsEffective } }
        @{ Expression = { $_.name } }
    )
    $colSort
}
'@

Assert-ComplexArrayElement 'Scriptblock in a one-line array subexpression' @'
function Get-Fixture {
    $tmpConnectorManagement = @($item.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1
    $tmpConnectorManagement
}
'@ -Expected 1 @('PSUseOneComplexArrayElementPerLine', 'own line')

Assert-ComplexArrayElement 'Scriptblock in a multiline array subexpression' @'
function Get-Fixture {
    $tmpConnectorManagement = @(
        $item.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }
    ) | Select-Object -First 1
    $tmpConnectorManagement
}
'@

Assert-ComplexArrayElement 'Hashtable in a one-line array subexpression' @'
function Get-Fixture {
    $colRows = @([pscustomobject]@{ Name = 'a' })
    $colRows
}
'@ -Expected 1

Assert-ComplexArrayElement 'Simplified Where-Object in an array subexpression' @'
function Get-Fixture {
    $colItem = @($items | Where-Object Name -like 'demo*')
    $colItem
}
'@

Assert-ComplexArrayElement 'Pipeline without a complex element' @'
function Get-Fixture {
    $objItem = @($items | Select-Object -First 1)
    $objItem
}
'@

Assert-ComplexArrayElement 'ForEach-Object in a one-line array subexpression' @'
function Get-Fixture {
    $colName = @($items | ForEach-Object { $_.Name })
    $colName
}
'@ -Expected 1

Assert-ComplexArrayElement 'Complex syntax in a string' @'
function Get-Fixture {
    $text = '@{ Name = ''a'' }, @{ Name = ''b'' }'
    $text
}
'@

Assert-ComplexArrayElement 'Complex syntax in a comment' @'
function Get-Fixture {
    # @{ Name = 'a' }, @{ Name = 'b' }
    Get-Thing
}
'@

Assert-ComplexArrayElement 'Internal module code is checked' @'
function Get-Fixture {
    $colSort = @(@{ Expression = { $_.name } }, @{ Expression = { $_.id } })
    $colSort
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'



Assert-ComplexArrayElement 'Test files are exempt' @'
function Get-Fixture {
    $colSort = @(@{ Expression = { $_.name } }, @{ Expression = { $_.id } })
    $colSort
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Complex array element rule checks passed: $script:caseCount cases."
