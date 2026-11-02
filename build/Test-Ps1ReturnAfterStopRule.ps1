<#
.SYNOPSIS
    Tests the return after Stop-PSFFunction lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a plain Stop-PSFFunction is followed
    by return, throw, or exit. Tail stops and stops that explicitly continue are
    exempt.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ReturnAfterStopDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('return-after-stop-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-ReturnAfterStop {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1ReturnAfterStopDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
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
