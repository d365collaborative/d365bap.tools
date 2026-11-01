<#
.SYNOPSIS
    Tests the central environment lookup lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that environment lookups go through
    Get-Environment instead of the public environment cmdlets. The implementation
    files are exempt.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1EnvironmentLookupDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('environment-lookup-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-EnvironmentLookup {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $FileName = 'Get-Fixture.ps1', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1EnvironmentLookupDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

$bap = @'
function Get-Fixture {
    $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1
}
'@
Assert-EnvironmentLookup 'BAP lookup' $bap 1 @('PSUseCentralEnvironmentLookup', 'Get-Environment', 'Get-BapEnvironment')

Assert-EnvironmentLookup 'Unified lookup with version details' @'
function Get-Fixture {
    $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1
}
'@ 1 @('Get-Environment -Unified -VersionDetails')

Assert-EnvironmentLookup 'Unified lookup without version details' @'
function Get-Fixture {
    $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails | Select-Object -First 1
}
'@ 1 @('Get-Environment -Unified instead')

Assert-EnvironmentLookup 'Abbreviated skip switch' @'
function Get-Fixture {
    $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersion | Select-Object -First 1
}
'@ 1 @('Get-Environment -Unified instead')

Assert-EnvironmentLookup 'Central lookup default shape' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
}
'@

Assert-EnvironmentLookup 'Central lookup unified shape' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId -Unified
}
'@

Assert-EnvironmentLookup 'Central lookup full shape' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId -Unified -VersionDetails
}
'@

Assert-EnvironmentLookup 'Module qualified command' $bap.Replace('Get-BapEnvironment', 'd365bap.tools\Get-BapEnvironment') 1 @('PSUseCentralEnvironmentLookup')

Assert-EnvironmentLookup 'Similar command name is ignored' @'
function Get-Fixture {
    $envObj = Get-BapEnvironmentD365App -EnvironmentId $EnvironmentId
}
'@

Assert-EnvironmentLookup 'Documentation mention is ignored' @'
function Get-Fixture {
    $message = "Try Get-BapEnvironment or Get-UnifiedEnvironment instead."
}
'@

Assert-EnvironmentLookup 'Two lookups in one file' @'
function Get-Fixture {
    $source = Get-BapEnvironment -EnvironmentId $SourceEnvironmentId
    $target = Get-UnifiedEnvironment -EnvironmentId $TargetEnvironmentId -SkipVersionDetails
}
'@ -Expected 2

Assert-EnvironmentLookup 'Implementation file is exempt' $bap -FileName 'Get-UnifiedEnvironment.ps1'
Assert-EnvironmentLookup 'Central function file is exempt' $bap -FileName 'Get-Environment.ps1'
Assert-EnvironmentLookup 'BAP cmdlet file is exempt' $bap -FileName 'Get-BapEnvironment.ps1'
Assert-EnvironmentLookup 'Internal functions are checked' $bap -Directory 'd365bap.tools/internal' -Expected 1
Assert-EnvironmentLookup 'Outside the module' $bap -Directory 'build'
Assert-EnvironmentLookup 'Test files are never checked' $bap -FileName 'Get-Ps1EnvironmentLookupRule.Tests.ps1'

Assert-EnvironmentLookup 'Central lookup assigned to envObj' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
}
'@

Assert-EnvironmentLookup 'Central lookup piped to the first result' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1
}
'@

Assert-EnvironmentLookup 'Central lookup assigned to another name' @'
function Get-Fixture {
    $environment = Get-Environment -EnvironmentId $EnvironmentId
}
'@ 1 @('named $envObj')

Assert-EnvironmentLookup 'Central lookup discarded to null' @'
function Get-Fixture {
    $null = Get-Environment -EnvironmentId $EnvironmentId
}
'@ 1 @('named $envObj')

Assert-EnvironmentLookup 'Central lookup without an assignment' @'
function Get-Fixture {
    Get-Environment -EnvironmentId $EnvironmentId
}
'@ 1 @('named $envObj')

Assert-EnvironmentLookup 'Central lookup inside try catch' @'
function Get-Fixture {
    try {
        $envObj = Get-Environment -EnvironmentId $EnvironmentId
    }
    catch {
        $envObj = $null
    }
}
'@ 1 @('Do not wrap Get-Environment in try/catch')

Assert-EnvironmentLookup 'Null check with null on the left' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
    if ($null -ne $envObj) {
        $name = $envObj.PpacEnvName
    }
}
'@ 1 @('is never null')

Assert-EnvironmentLookup 'Null check with null on the right' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
    if ($envObj -eq $null) {
        return
    }
}
'@ 1 @('is never null')

Assert-EnvironmentLookup 'Property null check is allowed' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
    if ($null -ne $envObj.PpacEnvName) {
        $name = $envObj.PpacEnvName
    }
}
'@

Assert-EnvironmentLookup 'Null check after a call without an id' @'
function Get-Fixture {
    $envObj = Get-Environment
    if ($null -ne $envObj) {
        $name = $envObj.PpacEnvName
    }
}
'@ 1 @('is never null')

Assert-EnvironmentLookup 'Null check in a nested function' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId

    function Test-Inner {
        if ($null -ne $envObj) {
            $name = $envObj.PpacEnvName
        }
    }
}
'@

Assert-EnvironmentLookup 'Truthiness check is allowed' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId
    if ($envObj) {
        $name = $envObj.PpacEnvName
    }
}
'@

$script:caseCount++
Write-Output "Environment lookup rule checks passed: $script:caseCount cases."
