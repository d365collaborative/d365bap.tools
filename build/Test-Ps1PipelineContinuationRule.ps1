<#
.SYNOPSIS
    Tests the pipeline continuation break lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a pipeline with more than one
    command breaks after each pipe, with the pipe at the end of the line.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1PipelineContinuationDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('pipeline-continuation-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-PipelineContinuation {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1PipelineContinuationDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-PipelineContinuation 'One-line pipeline' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1
    $envObj
}
'@ -Expected 1 @('PSUsePipelineContinuationBreak', 'Break the pipeline')

Assert-PipelineContinuation 'One-line pipeline with three commands' @'
function Get-Fixture {
    Get-Thing | Where-Object Name -like '*' | Select-Object -First 1
}
'@ -Expected 1

Assert-PipelineContinuation 'Trailing pipe' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId |
        Select-Object -First 1
    $envObj
}
'@

Assert-PipelineContinuation 'Leading pipe' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
        | Select-Object -First 1
    $envObj
}
'@ -Expected 1 @('Move `|` to the end of the previous line')

Assert-PipelineContinuation 'Leading pipe with a backtick' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId `
        | Select-Object -First 1
    $envObj
}
'@ -Expected 1

Assert-PipelineContinuation 'Three commands with trailing pipes' @'
function Get-Fixture {
    Get-Thing |
        Where-Object Name -like '*' |
        Select-Object -First 1
}
'@

Assert-PipelineContinuation 'Hashtable to ConvertTo-Json on the same line' @'
function Get-Fixture {
    $body = [ordered]@{
        name     = $Name
        ruleSets = @($RuleSet)
    } | ConvertTo-Json -Depth 20
    $body
}
'@

Assert-PipelineContinuation 'Hashtable to ConvertTo-Json on a new line' @'
function Get-Fixture {
    $body = [ordered]@{
        name     = $Name
        ruleSets = @($RuleSet)
    } |
        ConvertTo-Json -Depth 20
    $body
}
'@ -Expected 1 @('closing line')

Assert-PipelineContinuation 'Hashtable with a leading pipe' @'
function Get-Fixture {
    $body = [ordered]@{
        name     = $Name
        ruleSets = @($RuleSet)
    }
    | ConvertTo-Json -Depth 20
    $body
}
'@ -Expected 1

Assert-PipelineContinuation 'Multiline command to a command on the closing line' @'
function Get-Fixture {
    $objRoute = Get-Route `
        -Name 'fixture' | Select-Object -First 1
    $objRoute
}
'@ -Expected 1 @('Break the pipeline')

Assert-PipelineContinuation 'Multiline command to a command on a new line' @'
function Get-Fixture {
    $objRoute = Get-Route `
        -Name 'fixture' |
        Select-Object -First 1
    $objRoute
}
'@

Assert-PipelineContinuation 'Multiline command with a leading pipe' @'
function Get-Fixture {
    $objRoute = Get-Route `
        -Name 'fixture'
        | Select-Object -First 1
    $objRoute
}
'@ -Expected 1

Assert-PipelineContinuation 'Parenthesized multiline element on the closing line' @'
function Get-Fixture {
    $objRoute = (Get-Route `
        -Name 'fixture') | Select-Object -First 1
    $objRoute
}
'@

Assert-PipelineContinuation 'Single command' @'
function Get-Fixture {
    Get-Thing -Name 'x'
}
'@

Assert-PipelineContinuation 'Pipeline inside a scriptblock' @'
function Get-Fixture {
    $col | ForEach-Object {
        $_ | Select-Object -First 1
    }
}
'@ -Expected 2

Assert-PipelineContinuation 'Pipe inside a string' @'
function Get-Fixture {
    $text = 'a | b'
    $text
}
'@

Assert-PipelineContinuation 'Internal module code is checked' @'
function Get-Fixture {
    Get-Thing | Select-Object -First 1
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-PipelineContinuation 'Build scripts are exempt' @'
function Get-Fixture {
    Get-Thing | Select-Object -First 1
}
'@ -Directory 'build'

Assert-PipelineContinuation 'Tepp fixtures are exempt' @'
function Get-Fixture {
    Get-Thing | Select-Object -First 1
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-PipelineContinuation 'Test files are exempt' @'
function Get-Fixture {
    Get-Thing | Select-Object -First 1
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Pipeline continuation rule checks passed: $script:caseCount cases."
