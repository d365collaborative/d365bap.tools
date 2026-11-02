<#
.SYNOPSIS
    Tests the direct value string check lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a value wrapped in an interpolated
    string for a null or whitespace check is rejected, while a direct value and
    a composed string stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1DirectStringCheckDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('direct-string-check-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-DirectStringCheck {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1DirectStringCheckDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-DirectStringCheck 'Member expression' @'
function Get-Fixture {
    if (-not [string]::IsNullOrWhiteSpace("$($created.id)")) {
        $created.id
    }
}
'@ -Expected 1 @('PSUseDirectValueInStringCheck', 'IsNullOrWhiteSpace($created.id)')

Assert-DirectStringCheck 'Variable' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$policyName")) {
        $policyName = $colCurrent[0].PolicyId
    }
    $policyName
}
'@ -Expected 1 @('IsNullOrWhiteSpace($policyName)')

Assert-DirectStringCheck 'IsNullOrEmpty' @'
function Get-Fixture {
    if ([string]::IsNullOrEmpty("$tenantId")) {
        'missing'
    }
}
'@ -Expected 1 @('IsNullOrEmpty($tenantId)')

Assert-DirectStringCheck 'Nested property in a loop' @'
function Get-Fixture {
    foreach ($entry in $colEntries) {
        if (-not [string]::IsNullOrWhiteSpace("$($entry.tenant)")) {
            $entry.tenant
        }
    }
}
'@ -Expected 1

Assert-DirectStringCheck 'Direct member expression' @'
function Get-Fixture {
    if (-not [string]::IsNullOrWhiteSpace($created.id)) {
        $created.id
    }
}
'@

Assert-DirectStringCheck 'Direct variable' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace($policyName)) {
        $policyName = $colCurrent[0].PolicyId
    }
    $policyName
}
'@

Assert-DirectStringCheck 'Literal prefix' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("prefix $policyName")) {
        'missing'
    }
}
'@

Assert-DirectStringCheck 'Two expressions' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$first$last")) {
        'missing'
    }
}
'@

Assert-DirectStringCheck 'Two subexpressions' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$($first)$($last)")) {
        'missing'
    }
}
'@

Assert-DirectStringCheck 'Single-quoted literal' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace('literal')) {
        'missing'
    }
}
'@

Assert-DirectStringCheck 'Instance method is not checked' @'
function Get-Fixture {
    if ($checker.IsNullOrWhiteSpace("$policyName")) {
        'missing'
    }
}
'@

Assert-DirectStringCheck 'Other static method is not checked' @'
function Get-Fixture {
    $value = [int]::Parse("$count")
    $value
}
'@

Assert-DirectStringCheck 'Internal module code is checked' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$policyName")) {
        'missing'
    }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-DirectStringCheck 'Build scripts are exempt' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$policyName")) {
        'missing'
    }
}
'@ -Directory 'build/scripts'

Assert-DirectStringCheck 'Tepp fixtures are exempt' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$policyName")) {
        'missing'
    }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-DirectStringCheck 'Test files are exempt' @'
function Get-Fixture {
    if ([string]::IsNullOrWhiteSpace("$policyName")) {
        'missing'
    }
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Direct value string check rule checks passed: $script:caseCount cases."
