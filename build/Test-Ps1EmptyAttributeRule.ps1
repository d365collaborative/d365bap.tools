<#
.SYNOPSIS
    Tests the empty parameter attribute lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that empty [Parameter()] attributes are
    reported while attributes with arguments are allowed.
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
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'empty-attribute-rule'
$script:caseCount = 0

function Assert-EmptyAttribute {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ParameterContractDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName `
		-RuleName 'PSAvoidRedundantParameterAttribute' `
		-MessageLike 'Remove the empty*'
}

$empty = @'
function Get-Fixture {
    param (
        [Parameter()]
        [string] $Name
    )
}
'@
Assert-EmptyAttribute 'Empty attribute' $empty 1 @('PSAvoidRedundantParameterAttribute', '-Name', '[Parameter()]')

Assert-EmptyAttribute 'Mandatory argument' ($empty.Replace('[Parameter()]', '[Parameter(Mandatory)]'))

Assert-EmptyAttribute 'Position argument' ($empty.Replace('[Parameter()]', '[Parameter(Position = 0)]'))

Assert-EmptyAttribute 'Pipeline argument' ($empty.Replace('[Parameter()]', '[Parameter(ValueFromPipeline = $true)]'))

Assert-EmptyAttribute 'Parameter set argument' ($empty.Replace('[Parameter()]', "[Parameter(ParameterSetName = 'Excel')]"))

Assert-EmptyAttribute 'Explicit false argument' ($empty.Replace('[Parameter()]', '[Parameter(Mandatory = $false)]'))

Assert-EmptyAttribute 'No attributes' ($empty.Replace('[Parameter()]', ''))

Assert-EmptyAttribute 'Space before parentheses' ($empty.Replace('[Parameter()]', '[Parameter ()]')) -Expected 1

Assert-EmptyAttribute 'Other empty attributes' ($empty.Replace('[Parameter()]', "[CmdletBinding()]`n        [SupportsWildcards()]`n        [Parameter()]")) -Expected 1

Assert-EmptyAttribute 'Empty attribute with another attribute' ($empty.Replace('[Parameter()]', "[Parameter()]`n        [ValidateNotNullOrEmpty()]")) -Expected 1

Assert-EmptyAttribute 'Empty attribute with alias' ($empty.Replace('[Parameter()]', "[Parameter()]`n        [Alias('Login')]")) -Expected 1

Assert-EmptyAttribute 'Script-level parameter' @'
param (
    [Parameter()]
    [string] $Name
)
'@ -Expected 1

Assert-EmptyAttribute 'Multiple parameters' @'
function Get-Fixture {
    param (
        [Parameter()]
        [string] $Name,

        [Parameter()]
        [string] $Kind
    )
}
'@ -Expected 2 @('-Name', '-Kind')

Write-Output "Empty attribute rule checks passed: $script:caseCount cases."
