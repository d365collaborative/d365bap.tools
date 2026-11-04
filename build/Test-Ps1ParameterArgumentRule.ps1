<#
.SYNOPSIS
    Tests the redundant parameter argument lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that named arguments in a Parameter
    attribute are reported when they restate the attribute's default value.
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
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'parameter-argument-rule'
$script:caseCount = 0

function Assert-ParameterArgument {
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
		-MessageLike 'Remove the redundant*'
}

function Get-ParameterFixtureSource {
	param([string] $Arguments)
	@"
function Get-Fixture {
    param (
        [Parameter($Arguments)]
        [string] `$Name
    )
}
"@
}

Assert-ParameterArgument 'Mandatory false' (Get-ParameterFixtureSource 'Mandatory = $false') -Expected 1 -ExpectedText @('PSAvoidRedundantParameterAttribute', '-Name', 'Mandatory = $false')

Assert-ParameterArgument 'Mandatory false lowercase' (Get-ParameterFixtureSource 'mandatory = $false') -Expected 1

Assert-ParameterArgument 'ValueFromPipeline false' (Get-ParameterFixtureSource 'ValueFromPipeline = $false') -Expected 1

Assert-ParameterArgument 'ValueFromPipelineByPropertyName false' (Get-ParameterFixtureSource 'ValueFromPipelineByPropertyName = $false') -Expected 1

Assert-ParameterArgument 'ValueFromRemainingArguments false' (Get-ParameterFixtureSource 'ValueFromRemainingArguments = $false') -Expected 1

Assert-ParameterArgument 'HelpMessage null' (Get-ParameterFixtureSource 'HelpMessage = $null') -Expected 1

Assert-ParameterArgument 'Default parameter set name' (Get-ParameterFixtureSource "ParameterSetName = '__AllParameterSets'") -Expected 1

Assert-ParameterArgument 'Position minimum' (Get-ParameterFixtureSource 'Position = -2147483648') -Expected 1

Assert-ParameterArgument 'Mandatory true' (Get-ParameterFixtureSource 'Mandatory = $true')

Assert-ParameterArgument 'ValueFromPipeline true' (Get-ParameterFixtureSource 'ValueFromPipeline = $true')

Assert-ParameterArgument 'ValueFromPipelineByPropertyName true' (Get-ParameterFixtureSource 'ValueFromPipelineByPropertyName = $true')

Assert-ParameterArgument 'ValueFromRemainingArguments true' (Get-ParameterFixtureSource 'ValueFromRemainingArguments = $true')

Assert-ParameterArgument 'Position zero' (Get-ParameterFixtureSource 'Position = 0')

Assert-ParameterArgument 'Named parameter set' (Get-ParameterFixtureSource "ParameterSetName = 'Default'")

Assert-ParameterArgument 'HelpMessage text' (Get-ParameterFixtureSource "HelpMessage = 'Enter a name'")

Assert-ParameterArgument 'Typed mismatch' (Get-ParameterFixtureSource 'Mandatory = 0')

Assert-ParameterArgument 'Dynamic value' (Get-ParameterFixtureSource 'Mandatory = $script:isMandatory')

Assert-ParameterArgument 'Shorthand mandatory' (Get-ParameterFixtureSource 'Mandatory')

Assert-ParameterArgument 'Multiple redundant arguments' (Get-ParameterFixtureSource 'Mandatory = $false, ValueFromPipeline = $false') -Expected 2 @('-Name')

Assert-ParameterArgument 'Script-level parameter' @'
param (
    [Parameter(Mandatory = $false)]
    [string] $Name
)
'@ -Expected 1

Assert-ParameterArgument 'Other attributes are ignored' @'
function Get-Fixture {
    param (
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@

Write-Output "Parameter argument rule checks passed: $script:caseCount cases."
