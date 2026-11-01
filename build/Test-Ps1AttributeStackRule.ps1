<#
.SYNOPSIS
    Tests the attribute stack lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that Parameter attributes come first,
    followed by the remaining attributes, the type constraint and the name.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1AttributeStackDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('attribute-stack-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Stack {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1AttributeStackDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$standard = @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@
Assert-Stack 'Standard stack' $standard

Assert-Stack 'Validate before Parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('PSUseStandardAttributeStack', '-PolicyId')

Assert-Stack 'Alias before Parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Alias('Policy')]
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('-PolicyId')

Assert-Stack 'Multiple Parameter attributes first' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, ParameterSetName = 'NextLink')]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@

Assert-Stack 'No Parameter attribute' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Alias('Policy')]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@

Assert-Stack 'Blank line between attributes' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]

        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('Remove the blank line')

Assert-Stack 'Blank line before the type' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]

        [string] $PolicyId
    )
}
'@ -Expected 1 @('Remove the blank line')

Assert-Stack 'Type and name on separate lines' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PolicyId
    )
}
'@ -Expected 1 @('same line')

Assert-Stack 'Blank line before the name' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]

        $PolicyId
    )
}
'@ -Expected 1 @('Remove the blank line')

Assert-Stack 'Attribute after the type' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        [ValidateNotNullOrEmpty()]
        $PolicyId
    )
}
'@ -Expected 1 @('Stack [Parameter()] attributes first')

Assert-Stack 'Multi-line attribute' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@

Assert-Stack 'Plain parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $PolicyId
    )
}
'@

Assert-Stack 'Outside the functions folder' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}
'@ -Directory 'build'

Assert-Stack 'Only the file-named function is checked' @'
function Get-Helper {
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}

function Get-Fixture {
    param (
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}
'@

Write-Output "Attribute stack rule checks passed: $script:caseCount cases."
