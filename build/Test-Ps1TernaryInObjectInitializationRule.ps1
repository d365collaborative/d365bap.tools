<#
.SYNOPSIS
    Tests the ternary-in-object-initialization lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that an if/else used as a hashtable or
    pscustomobject value is written as a ternary operator. An if expression
    without an else, and a ternary value, stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1TernaryInObjectInitializationDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'ternary-initialization-rule'
$script:caseCount = 0

function Assert-TernaryInObjectInitialization {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1TernaryInObjectInitializationDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-TernaryInObjectInitialization 'Hashtable value' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $params
}
'@ -Expected 1 @('PSUseTernaryInObjectInitialization', 'ternary operator')

Assert-TernaryInObjectInitialization 'Multiline hashtable value' @'
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
'@ -Expected 1

Assert-TernaryInObjectInitialization 'Ordered dictionary value' @'
function Get-Fixture {
    $hashRuleSet = [ordered]@{
        id      = 'ConnectorManagement'
        version = if ([string]::IsNullOrWhiteSpace("$($objRuleSet.version)")) { '1.0' } else { $objRuleSet.version }
        inputs  = [ordered]@{ AllowedConnectorList = @($colAllowed) }
    }
    $hashRuleSet
}
'@ -Expected 1

Assert-TernaryInObjectInitialization 'Nested hashtable value' @'
function Get-Fixture {
    $hashPayload = @{
        properties = @{
            enabled = if ($Enabled) { $true } else { $false }
        }
    }
    $hashPayload
}
'@ -Expected 1

Assert-TernaryInObjectInitialization 'PSCustomObject value' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Name    = 'fixture'
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $objResult
}
'@ -Expected 1

Assert-TernaryInObjectInitialization 'Ternary value' @'
function Get-Fixture {
    $params = @{
        Version = $Version ? $Version.ToString() : $null
    }
    $params
}
'@

Assert-TernaryInObjectInitialization 'Multiline ternary value' @'
function Get-Fixture {
    $params = @{
        Version = $Version `
            ? $Version.ToString() `
            : $null
    }
    $params
}
'@

Assert-TernaryInObjectInitialization 'If expression without else' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() }
    }
    $params
}
'@

Assert-TernaryInObjectInitialization 'Hashtable outside a value' @'
function Get-Fixture {
    $params = @{
        Version = '1.0'
    }

    if ($Version) {
        $params.Version = $Version.ToString()
    }
    $params
}
'@

Assert-TernaryInObjectInitialization 'Internal module code is checked' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $params
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-TernaryInObjectInitialization 'Build scripts are exempt' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $params
}
'@ -Directory 'build/scripts'

Assert-TernaryInObjectInitialization 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $params
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-TernaryInObjectInitialization 'Test files are exempt' @'
function Get-Fixture {
    $params = @{
        Version = if ($Version) { $Version.ToString() } else { $null }
    }
    $params
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Ternary in object initialization rule checks passed: $script:caseCount cases."
