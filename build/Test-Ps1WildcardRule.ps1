<#
.SYNOPSIS
    Tests the wildcard parameter contract rule.

.DESCRIPTION
    Checks wildcard declarations and parameter comparisons, then records filter behavior that declaration changes could alter.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1WildcardParameterContractDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'wildcard-rule'
$script:caseCount = 0

function Assert-Wildcard {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1WildcardParameterContractDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

$missing = @'
function Get-Fixture {
    param (
        [string] $Name = "*"
    )
}
'@
Assert-Wildcard 'Missing attribute' $missing 1 @('PSUseWildcardParameterContract', '-Name', '[SupportsWildcards()]')

$present = $missing.Replace('[string] $Name', "[SupportsWildcards()]`n        [string] `$Name")
Assert-Wildcard 'Attribute present' $present

$fullyQualified = $missing.Replace('[string] $Name', "[System.Management.Automation.SupportsWildcardsAttribute()]`n        [string] `$Name")
Assert-Wildcard 'Fully qualified attribute' $fullyQualified

$noParentheses = $missing.Replace('[string] $Name', "[SupportsWildcards]`n        [string] `$Name")
Assert-Wildcard 'Type constraint is not an attribute' $noParentheses -Expected 1

Assert-Wildcard 'Non-wildcard default' ($missing.Replace('= "*"', '= "demo"'))

Assert-Wildcard 'Prefix wildcard default' ($missing.Replace('= "*"', '= "demo*"')) -Expected 1

Assert-Wildcard 'Question mark is not checked' ($missing.Replace('= "*"', '= "demo?"'))

Assert-Wildcard 'Character class is not checked' ($missing.Replace('= "*"', '= "demo[ab]"'))

Assert-Wildcard 'Single-quoted wildcard default' ($missing.Replace('= "*"', "= '*'")) -Expected 1

Assert-Wildcard 'No default value' ($missing.Replace('= "*"', ''))

Assert-Wildcard 'String array parameter' ($missing.Replace('[string] $Name', '[string[]] $Name')) -Expected 1

Assert-Wildcard 'Integer parameter' ($missing.Replace('[string] $Name = "*"', '[int] $Name = 0'))

Assert-Wildcard 'Object parameter' ($missing.Replace('[string] $Name = "*"', '[object] $Name = "*"'))

Assert-Wildcard 'Inline function parameter' @'
function Get-Fixture ([string] $Name = '*') {
}
'@ -Expected 1 -ExpectedText @('-Name')

Assert-Wildcard 'Script-level parameter' @'
param (
    [string] $Name = "*"
)
'@

Assert-Wildcard 'Nested function' @'
function Get-Fixture {
    function Get-Inner {
        param (
            [string] $Name = "*"
        )
    }
}
'@ -Expected 1 -ExpectedText @('-Name')

Assert-Wildcard 'Parameter name in message' @'
function Get-Fixture {
    param (
        [string] $Filter = "*"
    )
}
'@ -Expected 1 -ExpectedText @('-Filter')

Assert-Wildcard 'Multiple parameters' @'
function Get-Fixture {
    param (
        [string] $Name = "*",
        [string] $Kind = "*",
        [string] $Label = "demo"
    )
}
'@ -Expected 2 -ExpectedText @('-Name', '-Kind')

Assert-Wildcard 'Default expression is not constant' @'
function Get-Fixture {
    param (
        [string] $Name = $env:NAME
    )
}
'@

Assert-Wildcard 'Expandable string is not constant' @'
function Get-Fixture {
    param (
        [string] $Name = "$env:NAME*"
    )
}
'@

Assert-Wildcard 'Attribute without a star default' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name
    )
}
'@ -Expected 1 -ExpectedText @('does not default to')

Assert-Wildcard 'Attribute with a prefix default' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = "demo*"
    )
}
'@ -Expected 1 -ExpectedText @('does not default to')

Assert-Wildcard 'Attribute with a star default' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )
}
'@

Assert-Wildcard 'Bound parameter check for a wildcard parameter' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $used = $Name
    }
}
'@

Assert-Wildcard 'Contains method for a wildcard parameter' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($PSBoundParameters.Contains('Name')) {
        $used = $Name
    }
}
'@

Assert-Wildcard 'Bound parameter check outside an if' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $given = $PSBoundParameters.ContainsKey('Name')
}
'@

Assert-Wildcard 'Bound parameter check for another name' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($PSBoundParameters.ContainsKey('Other')) {
        $used = $Name
    }
}
'@

Assert-Wildcard 'Bound parameter check without the attribute' @'
function Get-Fixture {
    param (
        [string] $Name = 'demo'
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $used = $Name
    }
}
'@

Assert-Wildcard 'Bound parameter check in a nested function' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    function Test-Inner {
        if ($PSBoundParameters.ContainsKey('Name')) {
            $used = $Name
        }
    }
}
'@

Assert-Wildcard 'Bound parameter check with a variable name' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $key = 'Name'
    if ($PSBoundParameters.ContainsKey($key)) {
        $used = $Name
    }
}
'@

Assert-Wildcard 'Combined accepted declaration and use' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $Name
    }
    @('alpha') | Where-Object Name -like $Name
}
'@

Assert-Wildcard 'Combined declaration and comparison branches' @'
function Get-Fixture {
    param (
        [string] $Name = '*'
    )

    if ($Name -eq '*') {
        'all'
    }
}
'@ -Expected 2 -ExpectedText @('has a wildcard default value', 'is a wildcard filter')

Assert-Wildcard 'Internal helper function is in scope' $missing -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-Wildcard 'SDK wrappers are out of scope' $missing -Directory 'd365bap.tools/internal/sdk'

Assert-Wildcard 'Internal scripts are out of scope' $missing -Directory 'd365bap.tools/internal/scripts'

Assert-Wildcard 'Build scripts are out of scope' $missing -Directory 'build'

Assert-Wildcard 'Module tests are out of scope' $missing -Directory 'd365bap.tools/tests'

Assert-Wildcard 'Test files are out of scope' $missing -Directory 'd365bap.tools/functions' -FileName 'Get-Fixture.Tests.ps1'

# Runtime semantics: the declared wildcard default is a filter, so omission
# means "all", an exact value narrows to that value, and no match is empty.
$runtimeSource = @'
function Get-WildcardFilterFixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    @('alpha', 'beta', 'alphabet') | Where-Object { $_ -like $Name }
}
'@
$runtimeFolder = Join-Path $fixtureRoot 'd365bap.tools/functions'
$runtimePath = Join-Path $runtimeFolder 'Get-WildcardFilterFixture.ps1'
[IO.File]::WriteAllText($runtimePath, $runtimeSource.Replace("`r`n", "`n"))
. $runtimePath

$all = @(Get-WildcardFilterFixture)
if ($all.Count -ne 3) { throw "Runtime omitted default: expected 3 items, got $($all.Count)." }
$script:caseCount++

$exact = @(Get-WildcardFilterFixture -Name 'alpha')
if ($exact.Count -ne 1 -or $exact[0] -ne 'alpha') { throw "Runtime exact value: expected alpha, got $($exact -join ',')." }
$script:caseCount++

$pattern = @(Get-WildcardFilterFixture -Name 'alph*')
if ($pattern.Count -ne 2 -or $pattern -notcontains 'alphabet') { throw "Runtime pattern: expected alpha and alphabet, got $($pattern -join ',')." }
$script:caseCount++

$none = @(Get-WildcardFilterFixture -Name 'zeta*')
if ($none.Count -ne 0) { throw "Runtime no match: expected no items, got $($none.Count)." }
$script:caseCount++

$explicitAll = @(Get-WildcardFilterFixture -Name '*')
if ($explicitAll.Count -ne 3) { throw "Runtime explicit star: expected 3 items, got $($explicitAll.Count)." }
$script:caseCount++

Write-Output "Wildcard rule checks passed: $script:caseCount cases."
