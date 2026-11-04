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
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1HeadersVariableDiagnostic'
	)) {
	. $itemPath
}
. "$PSScriptRoot/ps1-lint/internal/Invoke-Ps1Analysis.ps1"
if (@(Get-Ps1DiagnosticRule | Where-Object { $_.Id -eq 'Get-Ps1HeadersVariableDiagnostic' }).Count -ne 1) {
	throw 'Get-Ps1HeadersVariableDiagnostic is not registered in Get-Ps1DiagnosticRule.'
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'headers-variable-rule'
$script:caseCount = 0

function Assert-HeadersVariable {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1HeadersVariableDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
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



Assert-HeadersVariable 'Test files are exempt' @'
function Get-Fixture {
    $envs = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = 'x' }
    $envs
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Headers variable rule checks passed: $script:caseCount cases."
