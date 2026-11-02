<#
.SYNOPSIS
    Tests the module command splatting lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a splat into a function defined in
    the module is rejected, while a splat into a system command stays allowed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ModuleSplattingDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('module-splatting-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-ModuleSplatting {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $RelativePath = 'd365bap.tools/functions/Get-Fixture.ps1',
		[hashtable] $ExtraFiles = @{}
	)

	$script:caseCount++
	$root = Join-Path $fixtureRoot "case-$script:caseCount"
	$path = Join-Path $root $RelativePath
	$null = New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))

	foreach ($itemKey in $ExtraFiles.Keys) {
		$extraPath = Join-Path $root $itemKey
		$null = New-Item -ItemType Directory -Path (Split-Path $extraPath -Parent) -Force
		[IO.File]::WriteAllText($extraPath, $ExtraFiles[$itemKey].Replace("`r`n", "`n"))
	}

	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1ModuleSplattingDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
}

Assert-ModuleSplatting 'Splat into a public function' @'
function Get-Target {
    param([string] $Name)
    $Name
}

function Get-Fixture {
    $params = @{ Name = 'x' }
    Get-Target @params
}
'@ -Expected 1 @('PSAvoidSplattingForModuleCommands', 'Get-Target', '@params')

Assert-ModuleSplatting 'Splat into an internal function' @'
function Get-Fixture {
    $params = @{ Name = 'x' }
    Get-InternalTarget @params
}
'@ -Expected 1 @('Get-InternalTarget') -ExtraFiles @{
	'd365bap.tools/internal/functions/Get-InternalTarget.ps1' = @'
function Get-InternalTarget {
    param([string] $Name)
    $Name
}
'@
}

Assert-ModuleSplatting 'Splat into a nested helper' @'
function Get-Fixture {
    function Invoke-Helper {
        param([string] $Name)
        $Name
    }

    $params = @{ Name = 'x' }
    Invoke-Helper @params
}
'@ -Expected 1 @('Invoke-Helper')

Assert-ModuleSplatting 'Splat PSBoundParameters into a module function' @'
function Get-Target {
    param([string] $Name)
    $Name
}

function Get-Fixture {
    param([string] $Name)

    Get-Target @PSBoundParameters
}
'@ -Expected 1 @('@PSBoundParameters')

Assert-ModuleSplatting 'Array splat into a module function' @'
function Get-Target {
    param([string] $Name)
    $Name
}

function Get-Fixture {
    $params = @('x')
    Get-Target @params
}
'@ -Expected 1

Assert-ModuleSplatting 'Module-qualified module function' @'
function Get-Target {
    param([string] $Name)
    $Name
}

function Get-Fixture {
    $params = @{ Name = 'x' }
    d365bap.tools\Get-Target @params
}
'@ -Expected 1

Assert-ModuleSplatting 'Case-insensitive module function name' @'
function Get-Target {
    param([string] $Name)
    $Name
}

function Get-Fixture {
    $params = @{ Name = 'x' }
    get-target @params
}
'@ -Expected 1

Assert-ModuleSplatting 'Two splats into a module function' @'
function Get-Target {
    param([string] $First, [string] $Second)
    "$First$Second"
}

function Get-Fixture {
    $first = @{ First = 'a' }
    $second = @{ Second = 'b' }
    Get-Target @first @second
}
'@ -Expected 2

Assert-ModuleSplatting 'Splat into Invoke-RestMethod' @'
function Get-Fixture {
    $params = @{
        Method = 'Post'
        Uri    = 'https://example.invalid'
    }
    Invoke-RestMethod @params
}
'@

Assert-ModuleSplatting 'Splat into New-Item' @'
function Get-Fixture {
    $params = @{
        Path     = 'x'
        ItemType = 'Directory'
    }
    New-Item @params
}
'@

Assert-ModuleSplatting 'Splat into an unknown command' @'
function Get-Fixture {
    $params = @{ Name = 'x' }
    Get-UnknownThing @params
}
'@

Assert-ModuleSplatting 'Splat into a module-qualified system command' @'
function Get-Fixture {
    $params = @{ Uri = 'https://example.invalid' }
    Microsoft.PowerShell.Utility\Invoke-RestMethod @params
}
'@

Assert-ModuleSplatting 'Explicit parameters to a module function' @'
function Get-Target {
    param([string] $Name)
    $Name
}

function Get-Fixture {
    Get-Target -Name 'x'
}
'@

Assert-ModuleSplatting 'Splat in a string and a comment' @'
function Get-Fixture {
    $text = 'Get-Target @params'
    # Get-Target @params
    $text
}
'@

Assert-ModuleSplatting 'OData property access is not a splat' @'
function Get-Fixture {
    $next = $response.'@odata.nextLink'
    $next
}
'@

Assert-ModuleSplatting 'Dynamic command name' @'
function Get-Fixture {
    $commandName = 'Get-Target'
    $params = @{ Name = 'x' }
    & $commandName @params
}
'@

Assert-ModuleSplatting 'Build scripts are exempt' @'
function Get-Fixture {
    $params = @{ Name = 'x' }
    Get-Target @params
}
'@ -RelativePath 'build/scripts/Get-Fixture.ps1'

Assert-ModuleSplatting 'Test files are exempt' @'
function Get-Fixture {
    $params = @{ Name = 'x' }
    Get-Target @params
}
'@ -RelativePath 'd365bap.tools/functions/Get-Fixture.Tests.ps1'

Assert-ModuleSplatting 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $params = @{ Name = 'x' }
    Get-Target @params
}
'@ -RelativePath 'd365bap.tools/internal/tepp/Get-Fixture.ps1'

Write-Output "Module splatting rule checks passed: $script:caseCount cases."
