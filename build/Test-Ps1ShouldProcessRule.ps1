<#
.SYNOPSIS
    Tests the ShouldProcess convention lint rule.

.DESCRIPTION
    Parses fixtures and checks declared SupportsShouldProcess, the ShouldProcess
    arguments, the human-friendly target and label, and the length and layout
    limits.
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

function Get-Fixture([string] $Affected = '$envObj.EnvName', [string] $Label = '"Assign ACP $($policy.PolicyId) - $($policy.Name)"', [string] $Call = '$PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)', [string] $Body = 'return', [string] $Condition = '-not ') {
	@"
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = `$true)]
    param ()

    `$envObj = [pscustomobject]@{ EnvName = 'env-01'; EnvId = 'env-id'; DisplayName = 'env display' }
    `$policy = [pscustomobject]@{ PolicyId = 'p-1'; Name = 'Policy One' }

    `$shouldAffected = $Affected
    `$shouldLabel = $Label

    if ($Condition$Call) { $Body }
}
"@
}

$compliant = Get-Fixture -Affected '"$($envObj.EnvName) ($($envObj.EnvId))"'
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

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'

    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('without declaring SupportsShouldProcess')

Assert-ShouldProcess 'One-argument call' (Get-Fixture -Call '$PSCmdlet.ShouldProcess($shouldAffected)') 1 @('two-argument form')
Assert-ShouldProcess 'Three-argument call' (Get-Fixture -Call "`$PSCmdlet.ShouldProcess(`$shouldAffected, `$shouldLabel, 'caption')") 1 @('two-argument form')

Assert-ShouldProcess 'Bare id as the first argument' (Get-Fixture -Call '$PSCmdlet.ShouldProcess($EnvironmentId, $shouldLabel)') 1 @('first ShouldProcess argument must be the local variable $shouldAffected')

Assert-ShouldProcess 'Literal as the second argument' (Get-Fixture -Call "`$PSCmdlet.ShouldProcess(`$shouldAffected, 'Do the thing')") 1 @('second ShouldProcess argument must be the local variable $shouldLabel')

Assert-ShouldProcess 'Bare id target' (Get-Fixture -Affected '$EnvironmentId') 1 @('an id alone is not human friendly')

Assert-ShouldProcess 'Object id property target' (Get-Fixture -Affected '$envObj.EnvId') 1 @('an id alone is not human friendly')

Assert-ShouldProcess 'Name with id target' (Get-Fixture -Affected '"$($envObj.EnvName) ($($envObj.EnvId))"')

Assert-ShouldProcess 'Display name target' (Get-Fixture -Affected '$envObj.DisplayName')

Assert-ShouldProcess 'Variable label' (Get-Fixture -Label '$envObj.EnvName') 1 @('must be a string literal')

Assert-ShouldProcess 'Bare id label' (Get-Fixture -Label '"$($policy.PolicyId)"') 1 @('must be a string literal')

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

Assert-ShouldProcess 'Bare SupportsShouldProcess argument' (Get-Fixture).Replace('SupportsShouldProcess = $true', 'SupportsShouldProcess')

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

Assert-ShouldProcess 'Affected target above the length limit' (Get-Fixture -Affected '"$($envObj.EnvName) ($($envObj.EnvId)) extra long suffix"') 1 @('keep it to 85 or fewer')

Assert-ShouldProcess 'Label above the length limit' (Get-Fixture -Label "'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'") 1 @('keep it to 125 or fewer')

Assert-ShouldProcess 'Blank line between the assignments' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName

    $shouldLabel = 'Do the thing'

    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('consecutive lines')

Assert-ShouldProcess 'No blank line before the if' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'
    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('one blank line')

Assert-ShouldProcess 'Missing negation' (Get-Fixture -Condition '') 1 @('Negate ShouldProcess with -not')

Assert-ShouldProcess 'Body is not a return' (Get-Fixture -Body "Write-Output 'confirmed'") 1 @('Return immediately')

Assert-ShouldProcess 'Call outside an if statement' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'

    $null = $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)
}
'@ 1 @('Wrap ShouldProcess in')

Assert-ShouldProcess 'Statement between the assignments and the if' @'
function Set-Fixture {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $envObj = [pscustomobject]@{ EnvName = 'env-01' }
    $shouldAffected = $envObj.EnvName
    $shouldLabel = 'Do the thing'
    Write-Output 'between'

    if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
}
'@ 1 @('directly before the ShouldProcess if statement')

Assert-ShouldProcess 'Internal functions are checked' $compliant -Directory 'd365bap.tools/internal'
Assert-ShouldProcess 'Outside the module' $compliant -Directory 'build'
Assert-ShouldProcess 'Test files are never checked' $compliant -FileName 'Set-Fixture.Tests.ps1'
Assert-ShouldProcess 'Tepp files are exempt' $compliant -FileName 'set.fixture.tepp.ps1' -Directory 'd365bap.tools/internal/tepp'

$script:caseCount++
Write-Output "ShouldProcess rule checks passed: $script:caseCount cases."
