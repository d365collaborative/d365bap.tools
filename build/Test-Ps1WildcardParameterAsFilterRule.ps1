<#
.SYNOPSIS
    Tests the wildcard filter parameter lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that a wildcard parameter is never
    compared with the literal '*'. Member expressions, other literals,
    non-wildcard parameters, scope-qualified variables, and shadowed locals
    stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1WildcardParameterAsFilterDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('wildcard-filter-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-WildcardFilter {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1WildcardParameterAsFilterDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-WildcardFilter 'Wildcard parameter compared with not-equal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Expected 1 @('PSUseWildcardParameterAsFilter', '-Name', "literal '*'")

Assert-WildcardFilter 'Wildcard parameter compared with equal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -eq '*') {
        'all'
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Case-sensitive comparison operators' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ceq '*') {
        'all'
    }
    if ($Name -cne '*') {
        $Name
    }
}
'@ -Expected 2

Assert-WildcardFilter 'Wildcard default without the attribute' @'
function Get-Fixture {
    param (
        [string] $Name = 'demo*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Like comparison' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -like '*') {
        'all'
    }
}
'@

Assert-WildcardFilter 'Comparison with another literal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne 'All') {
        $Name
    }
}
'@

Assert-WildcardFilter 'Member expression left operand' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    @($Name) | Where-Object { $_.Name -ne '*' }
}
'@

Assert-WildcardFilter 'Shadowed local variable' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $Name = 'All'
    if ($Name -ne '*') {
        $Name
    }
}
'@

Assert-WildcardFilter 'Non-wildcard parameter' @'
function Get-Fixture {
    param (
        [string] $Name
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@

Assert-WildcardFilter 'Scope-qualified variable' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($script:Name -ne '*') {
        $script:Name
    }
}
'@

Assert-WildcardFilter 'Nested function is not the parameter owner' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    function Test-Inner {
        param ([string] $Name)
        $Name -eq '*'
    }

    $Name
}
'@

Assert-WildcardFilter 'Internal helper functions are checked' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-WildcardFilter 'SDK wrappers are exempt' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Directory 'd365bap.tools/internal/sdk'

Assert-WildcardFilter 'Build scripts are exempt' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Directory 'build'

Write-Output "Wildcard filter rule checks passed: $script:caseCount cases."
