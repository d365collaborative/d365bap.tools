<#
.SYNOPSIS
    Tests the return after Stop-PSFFunction lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a plain Stop-PSFFunction is followed
    by return, throw, or exit before any later statement in the function runs.
    A function tail stop and a stop that explicitly continues are exempt.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ReturnAfterStopDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'return-after-stop-rule'
$script:caseCount = 0

function Assert-ReturnAfterStop {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ReturnAfterStopDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-ReturnAfterStop 'Stop followed by return' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
        return
    }
}
'@

Assert-ReturnAfterStop 'Stop followed by throw' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
        throw
    }
}
'@

Assert-ReturnAfterStop 'Stop followed by exit' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
        exit
    }
}
'@

Assert-ReturnAfterStop 'Tail stop' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
    }
}
'@

Assert-ReturnAfterStop 'Stop followed by another command' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
        Get-Thing
    }
}
'@ -Expected 1 @('PSUseReturnAfterStopPSFFunction', 'return, throw, or exit')

Assert-ReturnAfterStop 'Stop followed by continue' @'
function Get-Fixture {
    foreach ($item in $colSource) {
        if (-not $item) {
            Stop-PSFFunction -Message 'Missing'
            continue
        }
    }
}
'@ -Expected 1

Assert-ReturnAfterStop 'Stop followed by break' @'
function Get-Fixture {
    foreach ($item in $colSource) {
        if (-not $item) {
            Stop-PSFFunction -Message 'Missing'
            break
        }
    }
}
'@ -Expected 1

Assert-ReturnAfterStop 'StepsUpward is exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing' -StepsUpward 1
    Get-Thing
}
'@

Assert-ReturnAfterStop 'EnableException is exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing' -EnableException $true
    Get-Thing
}
'@

Assert-ReturnAfterStop 'Continue is exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing' -Continue
    Get-Thing
}
'@

Assert-ReturnAfterStop 'EnableException false is not exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing' -EnableException $false
    Get-Thing
}
'@ -Expected 1

Assert-ReturnAfterStop 'Comment between stop and return' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing'

    # stop here
    return
}
'@

Assert-ReturnAfterStop 'Catch followed by throw' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Stop-PSFFunction -Message 'Failed'
        throw
    }
}
'@

Assert-ReturnAfterStop 'Catch followed by a command' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Stop-PSFFunction -Message 'Failed'
        Get-Other
    }
}
'@ -Expected 1

Assert-ReturnAfterStop 'Qualified command name' @'
function Get-Fixture {
    PSFramework\Stop-PSFFunction -Message 'Missing'
    Get-Thing
}
'@ -Expected 1

Assert-ReturnAfterStop 'Stop after code in a tail block' @'
function Get-Fixture {
    if (-not $Value) {
        Get-Thing
        Stop-PSFFunction -Message 'Missing'
    }
}
'@

Assert-ReturnAfterStop 'Inner block followed by code' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
    }
    Get-Thing
}
'@ -Expected 1 @('PSUseReturnAfterStopPSFFunction', 'return, throw, or exit')

Assert-ReturnAfterStop 'Inner block followed by return' @'
function Get-Fixture {
    if (-not $Value) {
        Stop-PSFFunction -Message 'Missing'
    }
    return
}
'@

Assert-ReturnAfterStop 'Nested inner block followed by code' @'
function Get-Fixture {
    if (-not $Value) {
        if ($Value -eq 'Empty') {
            Stop-PSFFunction -Message 'Missing'
        }
    }
    Get-Thing
}
'@ -Expected 1

Assert-ReturnAfterStop 'Loop tail followed by code' @'
function Get-Fixture {
    foreach ($item in $colSource) {
        Stop-PSFFunction -Message 'Missing'
    }
    Get-Thing
}
'@ -Expected 1

Assert-ReturnAfterStop 'Try tail followed by code' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Stop-PSFFunction -Message 'Failed'
    }
    Get-Other
}
'@ -Expected 1

Assert-ReturnAfterStop 'Internal module code is checked' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing'
    Get-Thing
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-ReturnAfterStop 'Build scripts are exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing'
    Get-Thing
}
'@ -Directory 'build'

Assert-ReturnAfterStop 'Tepp fixtures are exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing'
    Get-Thing
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-ReturnAfterStop 'Test files are exempt' @'
function Get-Fixture {
    Stop-PSFFunction -Message 'Missing'
    Get-Thing
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Return after Stop-PSFFunction rule checks passed: $script:caseCount cases."
