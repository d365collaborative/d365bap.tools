<#
.SYNOPSIS
    Tests the ShouldProcess convention lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that a declared SupportsShouldProcess is
    implemented, that ShouldProcess uses two arguments, and that the target and
    label follow the $shouldAffected / $shouldLabel convention.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ShouldProcessDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('shouldprocess-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-ShouldProcess {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $FileName = 'Set-Fixture.ps1', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1ShouldProcessDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$compliant = @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string] $EnvironmentId
    )

    $envObj = [pscustomobject]@{ EnvName = 'env-01'; EnvId = 'env-id' }
    $policy = [pscustomobject]@{ PolicyId = 'p-1'; Name = 'Policy One' }

    $shouldAffected = $envObj.EnvName
    $shouldLabel = "Assign ACP $($policy.PolicyId) - $($policy.Name)"

    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@
Assert-ShouldProcess 'Compliant convention' $compliant

Assert-ShouldProcess 'Declared without a call' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    Write-Output 'no call'
}
'@ 1 @('never calls ShouldProcess')

Assert-ShouldProcess 'Call without the declaration' @'
function Set-Fixture {
    [CmdletBinding()]
    param ()

    $shouldAffected = 'env-01'
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('without declaring SupportsShouldProcess')

Assert-ShouldProcess 'One-argument call' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected)) { return }
}
'@ 1 @('two-argument form')

Assert-ShouldProcess 'Three-argument call' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel, 'caption')) { return }
}
'@ 1 @('two-argument form')

Assert-ShouldProcess 'Bare id as the first argument' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string] $EnvironmentId
    )

    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($EnvironmentId, $shouldLabel)) { return }
}
'@ 1 @('first ShouldProcess argument must be the local variable $shouldAffected')

Assert-ShouldProcess 'Literal as the second argument' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, 'Do the thing')) { return }
}
'@ 1 @('second ShouldProcess argument must be the local variable $shouldLabel')

Assert-ShouldProcess 'Bare id target' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string] $EnvironmentId
    )

    $shouldAffected = $EnvironmentId
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('an id alone is not human friendly')

Assert-ShouldProcess 'Object id property target' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01'; EnvId = 'env-id' }
    $shouldAffected = $envObj.EnvId
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('an id alone is not human friendly')

Assert-ShouldProcess 'Name with id target' ($compliant.Replace('$shouldAffected = $envObj.EnvName', '$shouldAffected = "$($envObj.EnvName) ($($envObj.EnvId))"'))

Assert-ShouldProcess 'Display name target' ($compliant.Replace('$shouldAffected = $envObj.EnvName', '$shouldAffected = $envObj.DisplayName'))

Assert-ShouldProcess 'Variable label' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = $envObj.EnvName
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('must be a string literal')

Assert-ShouldProcess 'Bare id label' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $policy = [pscustomobject]@{ PolicyId = 'p-1' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = "$($policy.PolicyId)"
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('must be a string literal')

Assert-ShouldProcess 'Missing target assignment' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('Assign $shouldAffected before calling ShouldProcess')

Assert-ShouldProcess 'Target assigned after the call' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
    $shouldAffected = 'env-01'
}
'@ 1 @('Assign $shouldAffected before calling ShouldProcess')

Assert-ShouldProcess 'SupportsShouldProcess false without a call' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $false)]
    param ()

    Write-Output 'no call'
}
'@

Assert-ShouldProcess 'Bare SupportsShouldProcess argument' ($compliant.Replace('SupportsShouldProcess = $true', 'SupportsShouldProcess'))

Assert-ShouldProcess 'Second call violates the convention' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
    if (-not $PSCmdlet.ShouldProcess($envObj, $shouldLabel)) { return }
}
'@ 1 @('first ShouldProcess argument must be the local variable $shouldAffected')

Assert-ShouldProcess 'Internal functions are checked' $compliant -Directory 'd365bap.tools/internal' -Expected 0
Assert-ShouldProcess 'Outside the module' $compliant -Directory 'build'
Assert-ShouldProcess 'Test files are never checked' $compliant -FileName 'Set-Fixture.Tests.ps1'
Assert-ShouldProcess 'Tepp files are exempt' $compliant -FileName 'set.fixture.tepp.ps1' -Directory 'd365bap.tools/internal/tepp'

$script:caseCount++
Write-Output "ShouldProcess rule checks passed: $script:caseCount cases."
