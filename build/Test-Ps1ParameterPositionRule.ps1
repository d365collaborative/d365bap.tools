<#
.SYNOPSIS
    Tests the explicit parameter position lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that Position arguments in a Parameter
    attribute are reported, except for the allowlisted cmdlet.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ParameterContractDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('parameter-position-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Position {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $FileName = 'Fixture.ps1', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1ParameterContractDiagnostic -Analysis $analysis | Where-Object RuleName -eq 'PSAvoidExplicitParameterPosition')
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$positional = @'
function Get-Fixture {
    param (
        [Parameter(Position = 0)]
        [string] $Name
    )
}
'@
Assert-Position 'Explicit position' $positional 1 @('PSAvoidExplicitParameterPosition', '-Name', 'Position = 0')

Assert-Position 'No position argument' ($positional.Replace('Position = 0', 'Mandatory = $true'))

Assert-Position 'Position zero' $positional -Expected 1

Assert-Position 'Position minus one' ($positional.Replace('Position = 0', 'Position = -1')) -Expected 1

Assert-Position 'Lowercase position' ($positional.Replace('Position = 0', 'position = 3')) -Expected 1

Assert-Position 'Position with other arguments' ($positional.Replace('Position = 0', 'Mandatory = $true, Position = 2')) -Expected 1

Assert-Position 'Multiple parameter sets' @'
function Get-Fixture {
    param (
        [Parameter(Position = 0, ParameterSetName = "Default")]
        [Parameter(Position = 0, ParameterSetName = "NextLink")]
        [string] $Name
    )
}
'@ -Expected 2

Assert-Position 'Script-level parameter' @'
param (
    [Parameter(Position = 0)]
    [string] $Name
)
'@ -Expected 1

Assert-Position 'Internal function' $positional -Directory 'd365bap.tools/internal' -Expected 1

Assert-Position 'Outside the module' $positional -Directory 'build'

Assert-Position 'Allowlisted cmdlet' $positional -FileName 'Get-PpacFinOpsAsset.ps1'

Assert-Position 'Allowlist is exact' $positional -FileName 'Get-PpacFinOpsAsset.Copy.ps1' -Expected 1

Assert-Position 'Test files are never checked' $positional -FileName 'Get-PpacFinOpsAsset.Tests.ps1'

Write-Output "Parameter position rule checks passed: $script:caseCount cases."
