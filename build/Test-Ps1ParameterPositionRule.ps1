<#
.SYNOPSIS
    Tests the explicit parameter position lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that Position arguments in a Parameter
    attribute are reported unless named parameter sets are present.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ParameterContractDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'parameter-position-rule'
$script:caseCount = 0

function Assert-Position {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ParameterContractDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName `
		-RuleName 'PSAvoidExplicitParameterPosition'
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

Assert-Position 'Negative position is not assumed redundant' ($positional.Replace('Position = 0', 'Position = -1'))

Assert-Position 'Non-declaration position is preserved' ($positional.Replace('Position = 0', 'position = 3'))

Assert-Position 'Position with other arguments' ($positional.Replace('Position = 0', 'Mandatory = $true, Position = 0')) -Expected 1

Assert-Position 'Multiple parameter sets' @'
function Get-Fixture {
    param (
        [Parameter(Position = 0, ParameterSetName = "Default")]
        [Parameter(Position = 0, ParameterSetName = "NextLink")]
        [string] $Name
    )
}
'@

Assert-Position 'Inline named set' 'function Get-Fixture ([Parameter(ParameterSetName = ''A'', Position = 0)] [string] $Name) {}'

Assert-Position 'Script-level parameter' @'
param (
    [Parameter(Position = 0)]
    [string] $Name
)
'@ -Expected 1

Assert-Position 'Internal function' $positional -Directory 'd365bap.tools/internal' -Expected 1

Assert-Position 'Outside the module' $positional -Directory 'build'

Assert-Position 'Formerly allowlisted cmdlet' $positional -FileName 'Get-PpacFinOpsAsset.ps1' -Expected 1

Assert-Position 'Allowlist is exact' $positional -FileName 'Get-PpacFinOpsAsset.Copy.ps1' -Expected 1

Assert-Position 'Test files are never checked' $positional -FileName 'Get-PpacFinOpsAsset.Tests.ps1'

Assert-Position 'Disabled positional binding preserves explicit slot' "function Get-Fixture { [CmdletBinding(PositionalBinding = `$false)] param([Parameter(Position = 0)][string] `$Name) }"
Assert-Position 'Script with disabled positional binding' "[CmdletBinding(PositionalBinding = `$false)] param([Parameter(Position = 0)][string] `$Name)"
Assert-Position 'Mixed reordered slots preserve entire block' 'function Get-Fixture { param([Parameter(Position = 0)][string] $First, [Parameter(Position = 3)][string] $Second) }'
Assert-Position 'Declaration-order positions are redundant' 'function Get-Fixture { [CmdletBinding()] param([Parameter(Position = 0)][string] $First, [Parameter(Position = 1)][string] $Second) }' -Expected 2
Assert-Position 'Dynamic binding remains outside redundancy proof' 'function Get-Fixture { [CmdletBinding()] param([Parameter(Position = 0)][string] $Name); dynamicparam { } }'

Assert-Position 'Script dynamic parameters stay outside redundancy proof' '[CmdletBinding()] param([Parameter(Position = 0)][string] $Name); dynamicparam { }'

Assert-Position 'Nested scriptblock uses its own binding policy' 'function Outer { param(); $block = { [CmdletBinding(PositionalBinding = $false)] param([Parameter(Position = 0)][string] $Name) } }'
Assert-Position 'Nested block ignores outer named parameter set' 'function Outer { param([Parameter(ParameterSetName = "Named")][string] $OuterName); $block = { param([Parameter(Position = 0)][string] $Name) } }' -Expected 1

Write-Output "Parameter position rule checks passed: $script:caseCount cases."

function Test-PositionBinding {
	[CmdletBinding(DefaultParameterSetName = 'ByName')]
	param (
		[Parameter(ParameterSetName = 'ByName', Position = 0)] [string] $Name,
		[Parameter(ParameterSetName = 'ById', Position = 0)] [int] $Id,
		[Parameter(ParameterSetName = 'ById', Mandatory = $true)] [switch] $ById
	)
	"$($PSCmdlet.ParameterSetName):$Name$Id"
}
if ((Test-PositionBinding 'abc') -ne 'ByName:abc0' -or (Test-PositionBinding 42 -ById) -ne 'ById:42') { throw 'Parameter-set positional binding changed.' }

function Test-PositionDisabled {
	[CmdletBinding(PositionalBinding = $false)]
	param([Parameter(Position = 0)][string] $Name)
	$Name
}
function Test-PositionDisabledWithoutSlot {
	[CmdletBinding(PositionalBinding = $false)]
	param([string] $Name)
}
if ((Test-PositionDisabled 'sample') -ne 'sample') { throw 'Explicit slot must still bind with positional binding disabled.' }
$withoutSlot = (Get-Command Test-PositionDisabledWithoutSlot).ParameterSets[0].Parameters | Where-Object Name -eq 'Name'
if ($withoutSlot.Position -ge 0) { throw 'Removing the explicit slot should remove positional binding in this fixture.' }
function Test-PositionBefore {
	[CmdletBinding()]
	param([Parameter(Position = 0)][string] $Name, [Parameter(Position = 1)][int] $Count)
	"$Name/$Count"
}
function Test-PositionAfter {
	[CmdletBinding()]
	param([string] $Name, [int] $Count)
	"$Name/$Count"
}
if ((Test-PositionBefore sample 2) -ne (Test-PositionAfter sample 2)) { throw 'Declaration-order slot removal must preserve binding.' }
