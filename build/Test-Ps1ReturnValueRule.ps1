<#
.SYNOPSIS
    Tests the return value lint rule.

.DESCRIPTION
    Parses fixtures and checks that return statements use a bare return.
    Class methods are exempt because PowerShell classes require return for
    method output.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ReturnValueDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'return-value-rule'
$script:caseCount = 0

function Assert-ReturnValue {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ReturnValueDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-ReturnValue 'Return with a variable value' @'
function Set-Fixture {
    return $value
}
'@ 1 @('PSAvoidReturnValue', 'Emit the value as output')

Assert-ReturnValue 'Bare return' @'
function Set-Fixture {
    if ($done) { return }
    Get-Thing
}
'@

Assert-ReturnValue 'Trailing bare return' @'
function Set-Fixture {
    Get-Thing
    return
}
'@ 1 @('trailing bare return')

Assert-ReturnValue 'Trailing bare return in a process block' @'
function Set-Fixture {
    process {
        Get-Thing
        return
    }
}
'@ 1 @('trailing bare return')

Assert-ReturnValue 'Trailing bare return in an end block' @'
function Set-Fixture {
    end {
        Get-Thing
        return
    }
}
'@ 1 @('trailing bare return')

Assert-ReturnValue 'Return null' @'
function Set-Fixture {
    return $null
}
'@ 1 @('emit $null explicitly')

Assert-ReturnValue 'Return an expression' @'
function Set-Fixture {
    return (Get-Thing)
}
'@ 1 @('Emit the value as output')

Assert-ReturnValue 'Return a command' @'
function Set-Fixture {
    return Get-Thing
}
'@ 1 @('Emit the value as output')

Assert-ReturnValue 'Return a pipeline' @'
function Set-Fixture {
    return Get-Thing | Select-Object -First 1
}
'@ 1 @('Emit the value as output')

Assert-ReturnValue 'Early return in an if branch' @'
function Set-Fixture {
    if ($done) {
        return 'finished'
    }

    Get-Thing
}
'@ 1 @('Emit the value as output')

Assert-ReturnValue 'Return inside a foreach loop' @'
function Set-Fixture {
    foreach ($item in $items) {
        return $item
    }
}
'@ 1 @('Emit the value as output')

Assert-ReturnValue 'Return inside a scriptblock' @'
function Set-Fixture {
    $items | ForEach-Object {
        return $_
    }
}
'@ 1 @('Emit the value as output')

Assert-ReturnValue 'Return at script scope in build' @'
return $value
'@ 1 @('Emit the value as output') -Directory 'build/scripts'

Assert-ReturnValue 'Build scripts are checked' @'
function Set-Fixture {
    return $value
}
'@ 1 @('Emit the value as output') -Directory 'build'

Assert-ReturnValue 'Class method return is exempt' @'
class TestClass {
    [string] Get-Value() {
        return 'value'
    }
}
'@

Assert-ReturnValue 'Test files are exempt' @'
function Set-Fixture {
    return $value
}
'@ -FileName 'Set-Fixture.Tests.ps1'

Assert-ReturnValue 'Test support files are exempt' @'
function Set-Fixture {
    return $value
}
'@ -Directory 'd365bap.tools/tests/general'


Assert-ReturnValue 'Outside module and build' @'
function Set-Fixture {
    return $value
}
'@ -Directory 'docs'

$script:caseCount++
Write-Output "Return value rule checks passed: $script:caseCount cases."
