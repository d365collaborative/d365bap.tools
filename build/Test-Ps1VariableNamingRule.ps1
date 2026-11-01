<#
.SYNOPSIS
    Tests the variable naming lint rule.

.DESCRIPTION
    Parses fixture scripts and checks the col, obj and tmp prefixes for
    collections, root objects, loop objects and foreach item variables.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1VariableNamingDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('variable-naming-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Variable {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $FileName = 'Get-Fixture.ps1', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1VariableNamingDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-Variable 'Collection prefix' @'
function Get-Fixture {
    $colItems = @(Get-Thing)
}
'@

Assert-Variable 'Collection without prefix' @'
function Get-Fixture {
    $items = @(Get-Thing)
}
'@ 1 @("prefix it with 'col'")

Assert-Variable 'Empty array' @'
function Get-Fixture {
    $items = @()
}
'@ 1 @("prefix it with 'col'")

Assert-Variable 'Array literal' @'
function Get-Fixture {
    $items = 1, 2, 3
}
'@ 1 @("prefix it with 'col'")

Assert-Variable 'Hashtable' @'
function Get-Fixture {
    $config = @{ Key = 'Value' }
}
'@ 1 @("prefix it with 'hash'")

Assert-Variable 'Hashtable with prefix' @'
function Get-Fixture {
    $hashConfig = @{ Key = 'Value' }
}
'@

Assert-Variable 'Collection prefix does not name a hashtable' @'
function Get-Fixture {
    $colConfig = @{ Key = 'Value' }
}
'@ 1 @("prefix it with 'hash'")

Assert-Variable 'Ordered hashtable' @'
function Get-Fixture {
    $config = [ordered]@{ Key = 'Value' }
}
'@ 1 @("prefix it with 'hash'")

Assert-Variable 'Hashtable constructor' @'
function Get-Fixture {
    $config = [hashtable]::new()
}
'@ 1 @("prefix it with 'hash'")

Assert-Variable 'Hashtable constructor with prefix' @'
function Get-Fixture {
    $hashConfig = [System.Collections.Hashtable]::new()
}
'@

Assert-Variable 'Collection constructor' @'
function Get-Fixture {
    $list = [System.Collections.ArrayList]::new()
}
'@ 1 @("prefix it with 'col'")

Assert-Variable 'Collection constructor with prefix' @'
function Get-Fixture {
    $colList = [System.Collections.ArrayList]::new()
}
'@

Assert-Variable 'Root object without prefix' @'
function Get-Fixture {
    $env = [pscustomobject]@{ Name = 'x' }
}
'@ 1 @("prefix it with 'obj'")

Assert-Variable 'Root object with prefix' @'
function Get-Fixture {
    $objEnv = [pscustomobject]@{ Name = 'x' }
}
'@

Assert-Variable 'New-Object without prefix' @'
function Get-Fixture {
    $env = New-Object psobject
}
'@ 1 @("prefix it with 'obj'")

Assert-Variable 'Single object from Select-Object' @'
function Get-Fixture {
    $policy = $colPolicies | Select-Object -First 1
}
'@ 1 @("prefix it with 'obj'")

Assert-Variable 'Single object from Select-Object with prefix' @'
function Get-Fixture {
    $objPolicy = $colPolicies | Select-Object -First 1
}
'@

Assert-Variable 'Foreach item without prefix' @'
function Get-Fixture {
    foreach ($thing in $colItems) {
        $used = $thing
    }
}
'@ 1 @('foreach item variable thing', "'item'")

Assert-Variable 'Foreach item with item prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $used = $itemThing
    }
}
'@

Assert-Variable 'Foreach item with tmp prefix' @'
function Get-Fixture {
    foreach ($tmpItem in $colItems) {
        $used = $tmpItem
    }
}
'@ 1 @('foreach item variable tmpItem', "'item'")

Assert-Variable 'Foreach source is a collection' @'
function Get-Fixture {
    $items = Get-Thing
    foreach ($itemThing in $items) {
        $used = $itemThing
    }
}
'@ 1 @("prefix it with 'col'")

Assert-Variable 'Foreach source with collection prefix' @'
function Get-Fixture {
    $colItems = Get-Thing
    foreach ($itemThing in $colItems) {
        $used = $itemThing
    }
}
'@

Assert-Variable 'Loop object without prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $asset = [pscustomobject]@{ Name = 'x' }
    }
}
'@ 1 @("prefix it with 'tmp'")

Assert-Variable 'Loop object with prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $tmpAsset = [pscustomobject]@{ Name = 'x' }
    }
}
'@

Assert-Variable 'Loop collection without prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $assets = @()
    }
}
'@ 1 @("declared inside a loop; prefix it with 'tmp'")

Assert-Variable 'Loop collection with tmp prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $tmpAssets = @()
    }
}
'@

Assert-Variable 'Loop collection with col prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $colAssets = @()
    }
}
'@ 1 @("declared inside a loop; prefix it with 'tmp'")

Assert-Variable 'Loop hashtable without prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $config = @{ Key = 'Value' }
    }
}
'@ 1 @("declared inside a loop; prefix it with 'tmp'")

Assert-Variable 'Loop hashtable with tmp prefix' @'
function Get-Fixture {
    foreach ($itemThing in $colItems) {
        $tmpConfig = @{ Key = 'Value' }
    }
}
'@

Assert-Variable 'ForEach-Object object without prefix' @'
function Get-Fixture {
    $colItems | ForEach-Object {
        $asset = [pscustomobject]@{ Name = 'x' }
    }
}
'@ 1 @("prefix it with 'tmp'")

Assert-Variable 'String literal is not checked' @'
function Get-Fixture {
    $messageString = 'text'
}
'@

Assert-Variable 'Member access is not checked' @'
function Get-Fixture {
    $baseUri = $objEnv.PpacEnvUri
}
'@

Assert-Variable 'Numeric for counter is not checked' @'
function Get-Fixture {
    for ($i = 0; $i -lt 3; $i++) {
        $used = $i
    }
}
'@

Assert-Variable 'Parameter is not checked' @'
function Get-Fixture {
    param (
        [string] $Name
    )

    $used = $Name
}
'@

Assert-Variable 'Scope qualified variable is not checked' @'
function Get-Fixture {
    $script:Thing = @()
}
'@

Assert-Variable 'Null assignment is not checked' @'
function Get-Fixture {
    $null = @()
}
'@

Assert-Variable 'Get-Environment result is owned by its own rule' @'
function Get-Fixture {
    $envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1
}
'@

Assert-Variable 'Get-Environment collection is checked' @'
function Get-Fixture {
    $envs = @(Get-Environment)
}
'@ 1 @("prefix it with 'col'")

Assert-Variable 'Outside the module' @'
function Get-Fixture {
    $items = @()
}
'@ -Directory 'build' -Expected 0

Assert-Variable 'Lint tooling internal scripts are checked' @'
function Get-Fixture {
    $items = @()
}
'@ 1 @("prefix it with 'col'") -Directory 'build/ps1-lint/internal'

Assert-Variable 'Lint tooling format scripts are checked' @'
function Get-Fixture {
    $items = @()
}
'@ 1 @("prefix it with 'col'") -Directory 'build/ps1-lint/ps1-format'

Assert-Variable 'Lint tooling test files are never checked' @'
function Get-Fixture {
    $items = @()
}
'@ -FileName 'Get-Ps1VariableNamingRule.Tests.ps1' -Directory 'build/ps1-lint/internal'

Assert-Variable 'Test files are never checked' @'
function Get-Fixture {
    $items = @()
}
'@ -FileName 'Get-Ps1VariableNamingRule.Tests.ps1'

$script:caseCount++
Write-Output "Variable naming rule checks passed: $script:caseCount cases."
