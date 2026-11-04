<#
.SYNOPSIS
    Tests optional parameter validation.

.DESCRIPTION
    Checks that [ValidateNotNullOrEmpty()] remains valid on optional parameters
    without a default, including runtime binding behavior.
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
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'validation-attribute-mandatory-rule'
$script:caseCount = 0

function Assert-ValidationAttribute {
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
		-RuleName 'PSUseValidationAttributeOnMandatory'
}

Assert-ValidationAttribute 'Optional parameter without a default' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@

Assert-ValidationAttribute 'Mandatory parameter' @'
function Get-Fixture {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@

Assert-ValidationAttribute 'Mandatory in a named parameter set' @'
function Get-Fixture {
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Next')]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@

Assert-ValidationAttribute 'Default string value' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name = 'fixture'
    )
}
'@

Assert-ValidationAttribute 'Default empty string value' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name = ''
    )
}
'@

Assert-ValidationAttribute 'Default null value' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name = $null
    )
}
'@

Assert-ValidationAttribute 'Attribute without parentheses is a type constraint' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty]
        [string] $Name
    )
}
'@

Assert-ValidationAttribute 'Empty Parameter attribute' @'
function Get-Fixture {
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@

Assert-ValidationAttribute 'Another validation attribute' @'
function Get-Fixture {
    param (
        [ValidateScript({ -not [string]::IsNullOrEmpty($_) })]
        [string] $Name
    )
}
'@

Assert-ValidationAttribute 'Script parameter is not judged' @'
param (
    [ValidateNotNullOrEmpty()]
    [string] $Name
)
'@

Assert-ValidationAttribute 'Internal helper functions are checked' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@ -Directory 'd365bap.tools/internal/functions'

Assert-ValidationAttribute 'SDK wrappers are exempt' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@ -Directory 'd365bap.tools/internal/sdk'

Assert-ValidationAttribute 'Build scripts are exempt' @'
function Get-Fixture {
    param (
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
}
'@ -Directory 'build'

Write-Output "Validation attribute on mandatory rule checks passed: $script:caseCount cases."

function Test-OptionalValidation {
	param([ValidateNotNullOrEmpty()] [string] $Name)
	$PSBoundParameters.ContainsKey('Name')
}
if (Test-OptionalValidation) { throw 'Omitted optional parameter was bound.' }
if (-not (Test-OptionalValidation -Name 'value')) { throw 'Explicit value was not bound.' }
$rejected = $false
try { Test-OptionalValidation -Name '' } catch [System.Management.Automation.ParameterBindingException] { $rejected = $true }
if (-not $rejected) { throw 'Explicit empty value was accepted.' }
