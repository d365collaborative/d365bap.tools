<#
.SYNOPSIS
    Tests the multiline if expression lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that an if/else used as an assignment
    value puts each branch on its own lines. A declared variable with an if
    statement and a ternary stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1MultilineIfExpressionDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('multiline-if-expression-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-MultilineIfExpression {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1MultilineIfExpressionDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-MultilineIfExpression 'Issue example' @'
function Get-Fixture {
    $fullId = if ($itemConnector -like '/providers/*') { $itemConnector } else { "/providers/Microsoft.PowerApps/apis/$itemConnector" }
    $fullId
}
'@ -Expected 1 @('PSUseMultilineIfExpression', 'separate lines')

Assert-MultilineIfExpression 'Short one-line if expression' @'
function Get-Fixture {
    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    $base
}
'@ -Expected 1

Assert-MultilineIfExpression 'Closing brace on the body line' @'
function Get-Fixture {
    $fullId = if ($itemConnector -like '/providers/*') {
        $itemConnector }
    else {
        "/providers/Microsoft.PowerApps/apis/$itemConnector"
    }
    $fullId
}
'@ -Expected 1

Assert-MultilineIfExpression 'Else on the closing brace line' @'
function Get-Fixture {
    $fullId = if ($itemConnector -like '/providers/*') {
        $itemConnector
    } else {
        "/providers/Microsoft.PowerApps/apis/$itemConnector"
    }
    $fullId
}
'@ -Expected 1

Assert-MultilineIfExpression 'Hashtable value' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $params
}
'@ -Expected 1

Assert-MultilineIfExpression 'Property assignment' @'
function Get-Fixture {
    $tmp = [pscustomobject]@{ DestinationVersion = $null }
    $tmp.DestinationVersion = if ($value -eq 'N/A') { [version]'0.0.0.0' } else { [version]$value }
    $tmp
}
'@ -Expected 1

Assert-MultilineIfExpression 'Multiline if expression' @'
function Get-Fixture {
    $fullId = if ($itemConnector -like '/providers/*') {
        $itemConnector
    }
    else {
        "/providers/Microsoft.PowerApps/apis/$itemConnector"
    }
    $fullId
}
'@

Assert-MultilineIfExpression 'Multiline hashtable value' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) {
            $Version.ToString()
        }
        else {
            $null
        }
    }
    $params
}
'@

Assert-MultilineIfExpression 'Elseif chain' @'
function Get-Fixture {
    $value = if ($Kind -eq 'A') {
        'a'
    }
    elseif ($Kind -eq 'B') {
        'b'
    }
    else {
        'c'
    }
    $value
}
'@

Assert-MultilineIfExpression 'Declared variable' @'
function Get-Fixture {
    $fullId = $null
    if ($itemConnector -like '/providers/*') {
        $fullId = $itemConnector
    }
    else {
        $fullId = "/providers/Microsoft.PowerApps/apis/$itemConnector"
    }
    $fullId
}
'@

Assert-MultilineIfExpression 'Ternary' @'
function Get-Fixture {
    $fullId = $itemConnector -like '/providers/*' ? $itemConnector : "/providers/Microsoft.PowerApps/apis/$itemConnector"
    $fullId
}
'@

Assert-MultilineIfExpression 'If statement without assignment' @'
function Get-Fixture {
    if ($itemConnector -like '/providers/*') { $itemConnector } else { $itemConnector }
}
'@

Assert-MultilineIfExpression 'Single line if without else' @'
function Get-Fixture {
    $value = if ($Kind) { 'a' }
    $value
}
'@

Assert-MultilineIfExpression 'Internal module code is checked' @'
function Get-Fixture {
    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    $base
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-MultilineIfExpression 'Build scripts are exempt' @'
function Get-Fixture {
    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    $base
}
'@ -Directory 'build/scripts'

Assert-MultilineIfExpression 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    $base
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-MultilineIfExpression 'Test files are exempt' @'
function Get-Fixture {
    $base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
    $base
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Multiline if expression rule checks passed: $script:caseCount cases."
