<#
.SYNOPSIS
    Tests the parameter spacing lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that every parameter after the first has
    a blank line before its attributes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ParameterSpacingDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('parameter-spacing-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Spacing {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1ParameterSpacingDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$spaced = @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [switch] $AsExcelOutput
    )
}
'@
Assert-Spacing 'Spaced parameters' $spaced

Assert-Spacing 'Missing blank line' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $PolicyId,
        [switch] $AsExcelOutput
    )
}
'@ -Expected 1 @('PSUseBlankLineBeforeParameter', '-AsExcelOutput')

Assert-Spacing 'First parameter is exempt' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $Name,

        [string] $Kind
    )
}
'@

Assert-Spacing 'Attributes require the blank line' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $Kind
    )
}
'@ -Expected 1 @('-Kind')

Assert-Spacing 'Blank line before attributes passes' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Kind
    )
}
'@

Assert-Spacing 'Third parameter still checked' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $Name,

        [string] $Kind,
        [string] $Label
    )
}
'@ -Expected 1 @('-Label')

Assert-Spacing 'Multi-line previous parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true
        )]
        [string] $Name,
        [string] $Kind
    )
}
'@ -Expected 1 @('-Kind')

Assert-Spacing 'Single-line param block' @'
function Get-Fixture {
    param ([string] $Name, [string] $Kind)
}
'@ -Expected 1 @('-Kind')

Assert-Spacing 'Outside the functions folder' @'
function Get-Fixture {
    param (
        [string] $Name,
        [string] $Kind
    )
}
'@ -Directory 'build'

Assert-Spacing 'Only the file-named function is checked' @'
function Get-Helper {
    param (
        [string] $Name,
        [string] $Kind
    )
}

function Get-Fixture {
    param (
        [string] $Name,

        [string] $Kind
    )
}
'@

Write-Output "Parameter spacing rule checks passed: $script:caseCount cases."
