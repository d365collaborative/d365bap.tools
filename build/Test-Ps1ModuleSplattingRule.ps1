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
. "$PSScriptRoot/ps1-lint/internal/Invoke-Ps1Analysis.ps1"
$analyzer = New-Ps1Analyzer
$ruleId = 'Get-Ps1ModuleSplattingDiagnostic'
if (@(Get-Ps1DiagnosticRule | Where-Object { $_.Id -eq $ruleId }).Count -ne 1) {
	throw "$ruleId is not registered in Get-Ps1DiagnosticRule."
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
		[hashtable] $ExtraFiles = @{},
		[switch] $AllRules
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

	$result = Invoke-Ps1Analysis -Path $path -Analyzer $analyzer
	if ($AllRules -and ($result.Failed -or $result.Diagnostics.Count -gt 0)) {
		throw "${Label}: accepted fixture must pass every owner: $($result.Diagnostics.Message -join '; ')"
	}
	$colDiagnostics = @($result.Diagnostics | Where-Object RuleName -eq 'PSAvoidSplattingForModuleCommands')
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
'@ -Expected 1 @('Unsupported splatted command target')

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

Assert-ModuleSplatting 'Expandable target' '& "Get-$name" @args' -Expected 1
Assert-ModuleSplatting 'Computed target' '& (Get-Command az) @args' -Expected 1
Assert-ModuleSplatting 'Dynamic external target' '& $az @args' -Expected 1
Assert-ModuleSplatting 'Scriptblock target' '& { param($x) $x } @args' -Expected 1
Assert-ModuleSplatting 'Multiple dynamic splats' '& $cmd @first @second' -Expected 1
Assert-ModuleSplatting 'Dynamic without splat' '& $cmd -Name x'
Assert-ModuleSplatting 'Literal external target' '& az @cliArgs'
Assert-ModuleSplatting 'Literal module target' "function Get-Target {} `n& 'Get-Target' @args" -Expected 1
Assert-ModuleSplatting 'Dynamic excluded scope' '& $cmd @args' -RelativePath 'build/scripts/example.ps1'

$standalonePath = Join-Path $fixtureRoot 'no-root/d365bap.tools/functions/Get-Dynamic.ps1'
$standaloneSource = "# location anchor`n& `$cmd @first @second"
$standaloneTokens = $null
$standaloneErrors = $null
$standaloneAst = [Management.Automation.Language.Parser]::ParseInput($standaloneSource, [ref]$standaloneTokens, [ref]$standaloneErrors)
if ($standaloneErrors.Count -gt 0) { throw 'Standalone fixture must parse.' }
$standaloneAnalysis = @{ Path = $standalonePath; Ast = $standaloneAst; Scope = (Get-Ps1AnalysisScope $standalonePath); Nodes = @{} }
$buildsBefore = $analyzer.Worker.RepositoryIndexBuilds.Count
$standaloneDiagnostics = @(Get-Ps1ModuleSplattingDiagnostic -Analysis $standaloneAnalysis -Worker $analyzer.Worker)
if ($standaloneDiagnostics.Count -ne 1 -or $standaloneDiagnostics[0].Line -ne 2 -or $standaloneDiagnostics[0].RuleName -ne 'PSAvoidSplattingForModuleCommands') {
	throw 'Unresolved splats must report once at their command without a module root.'
}
if ($analyzer.Worker.RepositoryIndexBuilds.Count -ne $buildsBefore) { throw 'Unresolved syntax must not load a repository index.' }
$script:caseCount++

Assert-ModuleSplatting 'Complete explicit call passes every analyzer rule' @'
function Get-Target {
    [OutputType([string])]
    param([string] $Name)
    $Name
}

function Get-Fixture {
<#
.SYNOPSIS
    Gets sample text.
.DESCRIPTION
    Retrieves a display value from the helper.
.PARAMETER Name
    Display value.
.EXAMPLE
    Get-Fixture -Name demo

    It selects -Name demo.
#>
    [OutputType([string])]
    param([string] $Name)
    Get-Target -Name $Name
}
'@ -AllRules

Write-Output "Module splatting rule checks passed: $script:caseCount cases."
