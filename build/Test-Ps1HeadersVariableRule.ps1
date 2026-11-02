<#
.SYNOPSIS
    Tests the headers variable lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that an inline headers hashtable is
    rejected, while a variable, a command, and an inline hashtable on another
    argument stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/internal/Invoke-Ps1Analysis.ps1"
$analyzer = New-Ps1Analyzer
$ruleId = 'Get-Ps1HeadersVariableDiagnostic'
if (@(Get-Ps1DiagnosticRule | Where-Object { $_.Id -eq $ruleId }).Count -ne 1) {
	throw "$ruleId is not registered in Get-Ps1DiagnosticRule."
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('headers-variable-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-HeadersVariable {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$result = Invoke-Ps1Analysis -Path $path -Analyzer $analyzer
	$colDiagnostics = @($result.Diagnostics | Where-Object RuleName -eq 'PSUseVariableForHeaders')
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	foreach ($itemDiagnostic in $colDiagnostics) {
		if ($itemDiagnostic.Severity -ne 'Error') { throw "${Label}: expected Error severity, got $($itemDiagnostic.Severity)." }
	}
	if ($Expected -gt 0 -and -not $result.Failed) { throw "${Label}: the shared analyzer did not fail the bad fixture." }
	$script:caseCount++
}

Assert-HeadersVariable 'Issue example' @'
function Get-Fixture {
    $tokenValue = 'x'
    $created = Invoke-RestMethod -Method Post `
        -Uri $uri `
        -Headers @{
        Authorization = "Bearer $tokenValue"
        Accept        = 'application/json'
    } `
        -Body $body `
        -ContentType 'application/json' `
        -ErrorAction Stop
    $created
}
'@ -Expected 1 @('PSUseVariableForHeaders', 'variable')

Assert-HeadersVariable 'One-line inline hashtable' @'
function Get-Fixture {
    $tokenValue = 'x'
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $tokenValue" } -ErrorAction Stop
    $envs
}
'@ -Expected 1

Assert-HeadersVariable 'Parenthesized hashtable' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers (@{ Authorization = 'x' }) -ErrorAction Stop
    $envs
}
'@ -Expected 1

Assert-HeadersVariable 'Ordered cast' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers ([ordered]@{ Authorization = 'x' }) -ErrorAction Stop
    $envs
}
'@ -Expected 1

Assert-HeadersVariable 'Another command with Headers' @'
function Get-Fixture {
    $response = Invoke-WebRequest -Method Get -Uri $uri -Headers @{ Authorization = 'x' }
    $response
}
'@ -Expected 1

Assert-HeadersVariable 'Variable headers' @'
function Get-Fixture {
    $hashHeaders = @{
        Authorization = 'x'
        Accept        = 'application/json'
    }

    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers $hashHeaders -ErrorAction Stop
    $envs
}
'@

Assert-HeadersVariable 'Member headers' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers $request.Headers -ErrorAction Stop
    $envs
}
'@

Assert-HeadersVariable 'Command headers' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers (Get-Headers) -ErrorAction Stop
    $envs
}
'@

Assert-HeadersVariable 'Inline hashtable on another parameter' @'
function Get-Fixture {
    $envs = Invoke-BapSdkRequest -Resource @{ Builder = 'Builder' } -Method 'GetAsync'
    $envs
}
'@

Assert-HeadersVariable 'Splat is not resolved' @'
function Get-Fixture {
    $params = @{
        Uri     = $uri
        Headers = @{ Authorization = 'x' }
    }

    $envs = Invoke-RestMethod @params -ErrorAction Stop
    $envs
}
'@

Assert-HeadersVariable 'Headers in a string and a comment' @'
function Get-Fixture {
    $text = 'Invoke-RestMethod -Headers @{ Authorization = ''x'' }'
    # Invoke-RestMethod -Headers @{ Authorization = 'x' }
    $text
}
'@

Assert-HeadersVariable 'Internal module code is checked' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = 'x' }
    $envs
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-HeadersVariable 'Build scripts are exempt' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = 'x' }
    $envs
}
'@ -Directory 'build/scripts'

Assert-HeadersVariable 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = 'x' }
    $envs
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-HeadersVariable 'Test files are exempt' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = 'x' }
    $envs
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Headers variable rule checks passed: $script:caseCount cases."
