<#
.SYNOPSIS
    Tests the parameter layout lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks parameter separation, attribute order,
    stack spacing, and the gap between the last bracket and the variable.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ParameterLayoutDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'parameter-layout-rule'
$script:caseCount = 0

function Assert-Layout {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ParameterLayoutDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

$standard = @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId,

        [Parameter()]
        [switch] $AsExcelOutput
    )
}
'@
Assert-Layout 'Standard layout' $standard

Assert-Layout 'Missing blank line between parameters' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $PolicyId,
        [switch] $AsExcelOutput
    )
}
'@ -Expected 1 @('PSUseStandardParameterLayout', '-AsExcelOutput', 'blank line')

Assert-Layout 'First parameter is exempt' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $Name,

        [string] $Kind
    )
}
'@

Assert-Layout 'Third parameter still checked' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $Name,

        [string] $Kind,
        [string] $Label
    )
}
'@ -Expected 1 @('-Label')

Assert-Layout 'Single-line param block' @'
function Get-Fixture {
    param ([string] $Name, [string] $Kind)
}
'@ -Expected 1 @('-Kind')

Assert-Layout 'Validate before Parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('Stack [Parameter()] attributes first', '-PolicyId')

Assert-Layout 'Multiple Parameter attributes first' @'
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

Assert-Layout 'ValidateSet before other attributes' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('a', 'b')]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@

Assert-Layout 'ValidateSet after other attributes' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('a', 'b')]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('ValidateSet', '-PolicyId')

Assert-Layout 'ValidateSet before Alias' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('a', 'b')]
        [Alias('Policy')]
        [string] $PolicyId
    )
}
'@

Assert-Layout 'ValidateSet before Parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [ValidateSet('a', 'b')]
        [Parameter(Mandatory = $true)]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('Stack [Parameter()] attributes first', '-PolicyId')

Assert-Layout 'No Parameter attribute' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Alias('Policy')]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@

Assert-Layout 'Blank line between attributes' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]

        [ValidateNotNullOrEmpty()]
        [string] $PolicyId
    )
}
'@ -Expected 1 @('Remove the blank line')

Assert-Layout 'Type and name on separate lines' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $PolicyId
    )
}
'@ -Expected 1 @('same line')

Assert-Layout 'Multi-line attribute' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true
        )]
        [string] $PolicyId
    )
}
'@

Assert-Layout 'Plain parameter' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string] $PolicyId
    )
}
'@

Assert-Layout 'No space between bracket and name' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PolicyId
    )
}
'@ -Expected 1 @('one space', 'PolicyId')

Assert-Layout 'Two spaces between bracket and name' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]  $PolicyId
    )
}
'@ -Expected 1 @('one space')

Assert-Layout 'No space after attribute without type' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]$PolicyId
    )
}
'@ -Expected 1 @('one space')

Assert-Layout 'Space after attribute without type' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] $PolicyId
    )
}
'@

Assert-Layout 'Scriptblock parameter is checked' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    process {
        $fn = {
            param ([string]$Value)
            $Value
        }
        & $fn 'x'
    }
}
'@ -Expected 1 @('Value')

Assert-Layout 'Outside the functions folder' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [string]$PolicyId,
        [switch] $AsExcelOutput
    )
}
'@ -Directory 'build'

Assert-Layout 'Only the file-named function is checked' @'
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

Assert-Layout 'Internal function layout is checked' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId,
        [switch] $AsExcelOutput
    )
}
'@ -Expected 1 @('-AsExcelOutput', 'blank line') -Directory 'd365bap.tools/internal/functions'

Assert-Layout 'Other internal scripts stay exempt' @'
function Get-Fixture {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyId,
        [switch] $AsExcelOutput
    )
}
'@ -Directory 'd365bap.tools/internal/scripts'

Write-Output "Parameter layout rule checks passed: $script:caseCount cases."
