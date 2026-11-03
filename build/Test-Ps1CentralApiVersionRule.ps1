<#
.SYNOPSIS
    Tests the central API version lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that request URLs and local version
    assignments read the version from the registry instead of a date literal.
    Here-strings, format-operator URLs, interpolated versions, and plain
    registry copies stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1CentralApiVersionDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'central-api-version-rule'
$script:caseCount = 0

function Assert-ApiVersion {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1CentralApiVersionDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-ApiVersion 'Double-quoted literal URL' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/authorization/roleAssignments?api-version=2024-10-01"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('PSUseCentralApiVersion', 'BapApiVersions')

Assert-ApiVersion 'Single-quoted literal URL' @'
function Get-Fixture {
    $uri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/locations?api-version=2021-04-01'
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('Do not write the API version')

Assert-ApiVersion 'Literal version assignment' @'
function Get-Fixture {
    $apiVersion = '2024-10-01'
    $uri = "/environments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('Do not assign an API version literal')

Assert-ApiVersion 'Scoped literal version assignment' @'
function Get-Fixture {
    $script:ApiVersion = "2022-03-01-preview"
    $uri = "/roles?api-version=$script:ApiVersion"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1

Assert-ApiVersion 'Version chosen by an if expression' @'
function Get-Fixture {
    $apiVersion = if ($Preview) { '2022-03-01-preview' } else { '2024-10-01' }
    $uri = "/environments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('Do not assign an API version literal')

Assert-ApiVersion 'Interpolated version' @'
function Get-Fixture {
    $apiVersion = $script:BapSdkApiVersion
    $uri = "https://api.powerplatform.com/authorization/roleAssignments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@

Assert-ApiVersion 'Registry copy' @'
function Get-Fixture {
    $apiVersion = $script:BapApiVersions.PowerPlatform
    $uri = "/environments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@

Assert-ApiVersion 'Format operator URL' @'
function Get-Fixture {
    $uri = 'https://api.powerplatform.com/authorization/roleAssignments?api-version={0}' -f $script:BapApiVersions.PowerPlatform
    Invoke-RestMethod -Uri $uri
}
'@

Assert-ApiVersion 'Format operator on a continuation line' @'
function Get-Fixture {
    $uri = 'https://api.powerplatform.com/authorization/roleAssignments?api-version={0}' `
        -f $script:BapApiVersions.PowerPlatform
    Invoke-RestMethod -Uri $uri
}
'@

Assert-ApiVersion 'Non-date assignment' @'
function Get-Fixture {
    $apiVersion = 'latest'
    $uri = "/environments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@

$doubleHereString = @(
	'function Get-Fixture {'
	'    $example = @"'
	'    GET https://api.powerplatform.com/environments?api-version=2024-10-01'
	'"@'
	'    $example'
	'}'
) -join "`n"
Assert-ApiVersion 'Documented example URL in a double-quoted here-string' $doubleHereString

$singleHereString = @(
	'function Get-Fixture {'
	'    $example = @'''
	'    GET https://api.powerplatform.com/environments?api-version=2024-10-01'
	'''@'
	'    $example'
	'}'
) -join "`n"
Assert-ApiVersion 'Documented example URL in a single-quoted here-string' $singleHereString

Assert-ApiVersion 'Registry file may assign a literal version' @'
$apiVersion = '2024-10-01'
'@ -Directory 'd365bap.tools/internal/scripts' -FileName 'initialize-sdk.ps1'

Assert-ApiVersion 'Registry file still rejects a literal URL' @'
$uri = "https://api.powerplatform.com/environments?api-version=2024-10-01"
'@ -Directory 'd365bap.tools/internal/scripts' -FileName 'initialize-sdk.ps1' -Expected 1

Assert-ApiVersion 'Outside the module' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=2024-10-01"
}
'@ -Directory 'build'

Assert-ApiVersion 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=2024-10-01"
}
'@ -Directory 'd365bap.tools/internal/tepp' -Expected 0

Assert-ApiVersion 'Test files are exempt' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=2024-10-01"
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Central API version rule checks passed: $script:caseCount cases."
