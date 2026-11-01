<#
.SYNOPSIS
    Tests the wildcard parameter lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that string parameters with wildcard
    defaults require a SupportsWildcards attribute.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ParameterContractDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('wildcard-rule-' + [guid]::NewGuid().ToString('N') + '.ps1')
$script:caseCount = 0

function Assert-Wildcard {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @())
	[IO.File]::WriteAllText($fixturePath, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $fixturePath
	$colDiagnostics = @(Get-Ps1ParameterContractDiagnostic -Analysis $analysis | Where-Object RuleName -eq 'PSUseSupportsWildcards')
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

$missing = @'
function Get-Fixture {
    param (
        [string] $Name = "*"
    )
}
'@
Assert-Wildcard 'Missing attribute' $missing 1 @('PSUseSupportsWildcards', '-Name', '[SupportsWildcards()]')

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
'@ -Expected 1 -ExpectedText @('PSBoundParameters', '-Name')

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
'@ -Expected 1 -ExpectedText @('PSBoundParameters', '-Name')

Assert-Wildcard 'Bound parameter check outside an if' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $given = $PSBoundParameters.ContainsKey('Name')
}
'@ -Expected 1

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

Write-Output "Wildcard rule checks passed: $script:caseCount cases."
