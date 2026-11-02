<#
.SYNOPSIS
    Tests the single catch error channel lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a catch block does not both log with
    Write-PSFMessage and stop with Stop-PSFFunction. Diagnostic levels, nested
    handlers, and nested functions stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1SingleCatchErrorChannelDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('single-catch-error-channel-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-CatchChannel {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1SingleCatchErrorChannelDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-CatchChannel 'Log and stop' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@ -Expected 1 @('PSUseSingleCatchErrorChannel', 'Write-PSFMessage', 'Stop-PSFFunction')

Assert-CatchChannel 'Log only' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
    }
}
'@

Assert-CatchChannel 'Stop only' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Stop-PSFFunction -Message 'Failed'
    }
}
'@

Assert-CatchChannel 'Verbose log and stop' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Verbose -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@

Assert-CatchChannel 'Debug log and stop' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Debug -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@

Assert-CatchChannel 'Log without a level and stop' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@

Assert-CatchChannel 'Log in a branch and stop outside' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        if ($_.Exception.Message -like '*retry*') {
            Write-PSFMessage -Level Important -Message $_.Exception.Message
            return
        }
        Stop-PSFFunction -Message 'Failed'
    }
}
'@

Assert-CatchChannel 'Log and stop in the same branch' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        if ($_.Exception.Message -like '*retry*') {
            Write-PSFMessage -Level Important -Message $_.Exception.Message
            Stop-PSFFunction -Message 'Failed'
        }
        return
    }
}
'@ -Expected 1

Assert-CatchChannel 'Log and stop in opposite branches' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        if ($_.Exception.Message -like '*retry*') {
            Write-PSFMessage -Level Important -Message $_.Exception.Message
        }
        else {
            Stop-PSFFunction -Message 'Failed'
        }
    }
}
'@

Assert-CatchChannel 'Nested handler owns its stop' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        try {
            Get-Other
        }
        catch {
            Stop-PSFFunction -Message 'Failed'
        }
    }
}
'@

Assert-CatchChannel 'Nested function owns its stop' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        function Stop-Inner {
            Stop-PSFFunction -Message 'Failed'
        }
        Stop-Inner
    }
}
'@

Assert-CatchChannel 'Qualified command names' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        PSFramework\Write-PSFMessage -Level Warning -Message $_.Exception.Message
        PSFramework\Stop-PSFFunction -Message 'Failed'
    }
}
'@ -Expected 1

Assert-CatchChannel 'Two catch blocks' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch [System.InvalidOperationException] {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
    }
}
'@ -Expected 1

Assert-CatchChannel 'Script scope catch' @'
try {
    Get-Thing
}
catch {
    Write-PSFMessage -Level Important -Message $_.Exception.Message
    Stop-PSFFunction -Message 'Failed'
}
'@ -Expected 1

Assert-CatchChannel 'Build scripts are exempt' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@ -Directory 'build'

Assert-CatchChannel 'Tepp fixtures are exempt' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-CatchChannel 'Test files are exempt' @'
function Get-Fixture {
    try {
        Get-Thing
    }
    catch {
        Write-PSFMessage -Level Important -Message $_.Exception.Message
        Stop-PSFFunction -Message 'Failed'
    }
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Single catch error channel rule checks passed: $script:caseCount cases."
