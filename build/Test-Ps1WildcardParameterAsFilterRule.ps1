<#
.SYNOPSIS
    Tests the wildcard parameter use half of the contract rule.

.DESCRIPTION
    Checks declared wildcard comparisons, scope qualifiers, reassignment, and nested-function ownership.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1WildcardParameterContractDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('wildcard-filter-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-WildcardFilter {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	if ($analysis.ParseErrors.Count -gt 0) { throw "Invalid fixture ${Label}: $($analysis.ParseErrors.Message -join '; ')" }
	$colDiagnostics = @(Get-Ps1WildcardParameterContractDiagnostic -Analysis $analysis)
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
'@ -Expected 1 @('PSUseWildcardParameterContract', '-Name', "literal '*'")

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

Assert-WildcardFilter 'Parameter name comparison is case-insensitive' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($name -ne '*') {
        $name
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Explicit insensitive comparison operators' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ieq '*') {
        'all'
    }
    if ($Name -ine '*') {
        $Name
    }
}
'@ -Expected 2

Assert-WildcardFilter 'Literal left of equal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ('*' -eq $Name) {
        'all'
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Literal left of not-equal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ('*' -ne $Name) {
        $Name
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Literal left of case-sensitive equal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ('*' -ceq $Name) {
        'all'
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Literal left of case-sensitive not-equal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ('*' -cne $Name) {
        $Name
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Double-quoted star literal' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -eq "*") {
        'all'
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Wildcard default without the attribute' @'
function Get-Fixture {
    param (
        [string] $Name = 'demo*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Expected 2 @('has a wildcard default value', 'is a wildcard filter')

Assert-WildcardFilter 'Attribute without the star default and a comparison' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = 'demo*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Expected 2 @('does not default to', 'is a wildcard filter')

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

Assert-WildcardFilter 'Comparison with a variable pattern' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $pattern = '*'
    if ($Name -ne $pattern) {
        $Name
    }
}
'@

Assert-WildcardFilter 'Comparison with another variable' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $other = 'all'
    if ($Name -eq $other) {
        'all'
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

Assert-WildcardFilter 'Assignment does not hide the declared parameter' @'
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
'@ -Expected 1 @('is a wildcard filter')

Assert-WildcardFilter 'Self-assignment does not hide the declared parameter' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $Name = $Name
    if ($Name -eq '*') {
        'all'
    }
}
'@ -Expected 1 @('is a wildcard filter')

Assert-WildcardFilter 'Local qualification is the declared parameter' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($local:Name -ne '*') {
        $local:Name
    }
    if ('*' -eq $local:Name) {
        'all'
    }
}
'@ -Expected 2

Assert-WildcardFilter 'Local qualification is case-insensitive' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($LOCAL:Name -ne '*') {
        $Name
    }
}
'@ -Expected 1

Assert-WildcardFilter 'Script-qualified variable is not the parameter' @'
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

Assert-WildcardFilter 'Global-qualified variable is not the parameter' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($global:Name -eq '*') {
        $global:Name
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

Assert-WildcardFilter 'Nested owner checks its own wildcard parameter' @'
function Get-Fixture {
    function Test-Inner {
        param (
            [SupportsWildcards()]
            [string] $Name = '*'
        )

        if ($Name -ne '*') {
            $Name
        }
    }
}
'@ -Expected 1 @('-Name')

Assert-WildcardFilter 'Nested helper read of the parent parameter is not the parent use' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    function Test-Inner {
        $Name -ne '*'
    }

    $Name
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

Assert-WildcardFilter 'Valid presence check remains clean' @'
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

Assert-WildcardFilter 'Inline function parameter' @'
function Get-Fixture ([SupportsWildcards()][string] $Name = '*') {
    if ($Name -ne '*') {
        $Name
    }
}
'@ -Expected 1

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

Assert-WildcardFilter 'Internal scripts are exempt' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Directory 'd365bap.tools/internal/scripts'

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

Assert-WildcardFilter 'Test files are exempt' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    if ($Name -ne '*') {
        $Name
    }
}
'@ -Directory 'd365bap.tools/functions' -FileName 'Get-Fixture.Tests.ps1'

Assert-WildcardFilter 'Parenthesized comparison does not evade contract' "function Get-Fixture { param([SupportsWildcards()][string] `$Name = '*'); if ((`$Name) -eq ('*')) { } }" -Expected 1
Assert-WildcardFilter 'Reversed parenthesized local comparison' "function Get-Fixture { param([SupportsWildcards()][string] `$Name = '*'); if (('*') -cne (`$local:Name)) { } }" -Expected 1

Write-Output "Wildcard filter rule checks passed: $script:caseCount cases."
