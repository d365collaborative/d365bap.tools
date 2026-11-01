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
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ReturnValueDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('return-value-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-ReturnValue {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Set-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1ReturnValueDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
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

Assert-ReturnValue 'Tepp files are exempt' @'
function Set-Fixture {
    return $value
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-ReturnValue 'Outside module and build' @'
function Set-Fixture {
    return $value
}
'@ -Directory 'docs'

$script:caseCount++
Write-Output "Return value rule checks passed: $script:caseCount cases."
