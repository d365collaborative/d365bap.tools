<#
.SYNOPSIS
    Tests the declared output type lint rule.

.DESCRIPTION
    Parses fixture functions and checks that public and internal functions
    declare a non-empty OutputType, that PSF type names match, and that
    System.Object alone is rejected.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1OutputTypeDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'output-type-rule'
$script:caseCount = 0

function Assert-OutputType {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1OutputTypeDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-OutputType 'Missing OutputType' @'
function Set-Fixture {
    param()
    Get-Thing
}
'@ 1 @('must declare [OutputType()]')

Assert-OutputType 'Empty OutputType' @'
function Set-Fixture {
    [OutputType()]
    param()
    Get-Thing
}
'@ 1 @('must declare at least one type')

Assert-OutputType 'System.Object is too broad' @'
function Set-Fixture {
    [OutputType([System.Object])]
    param()
    Get-Thing
}
'@ 1 @('only declares System.Object')

Assert-OutputType 'System.Object array is too broad' @'
function Set-Fixture {
    [OutputType([System.Object[]])]
    param()
    Get-Thing
}
'@ 1 @('only declares System.Object')

Assert-OutputType 'PSCustomObject is allowed for anonymous objects' @'
function Set-Fixture {
    [OutputType([PSCustomObject])]
    param()
    [pscustomobject]@{ Name = 'x' }
}
'@

Assert-OutputType 'Hashtable is allowed' @'
function Set-Fixture {
    [OutputType([hashtable])]
    param()
    @{ Key = 'Value' }
}
'@

Assert-OutputType 'String is allowed' @'
function Set-Fixture {
    [OutputType([string])]
    param()
    'text'
}
'@

Assert-OutputType 'Void is allowed' @'
function Set-Fixture {
    [OutputType([void])]
    param()
    Write-PSFMessage -Message 'no output'
}
'@

Assert-OutputType 'Void mixed with another type' @'
function Set-Fixture {
    [OutputType([void], [string])]
    param()
    'text'
}
'@ 1 @('mixes [void]')

Assert-OutputType 'System.Object with a specific type is allowed' @'
function Set-Fixture {
    [OutputType([System.Object], [string])]
    param()
    'text'
}
'@

Assert-OutputType 'PSF type matches' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.Example')]
    param()
    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@

Assert-OutputType 'PSF collection type matches' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.Example[]')]
    param()
    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@

Assert-OutputType 'PSF type with a generic array OutputType' @'
function Set-Fixture {
    [OutputType([System.Object[]])]
    param()
    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@ 1 @("does not declare 'D365Bap.Tools.Example'")

Assert-OutputType 'PSF type with a PSCustomObject OutputType' @'
function Set-Fixture {
    [OutputType([PSCustomObject])]
    param()
    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@ 1 @("does not declare 'D365Bap.Tools.Example'")

Assert-OutputType 'PSF output without OutputType' @'
function Set-Fixture {
    param()
    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@ 1 @('must declare [OutputType()]')

Assert-OutputType 'PSTypeName matches' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.Example')]
    param()
    [pscustomobject]@{ PSTypeName = 'D365Bap.Tools.Example'; Name = 'x' }
}
'@

Assert-OutputType 'Multiple PSF types all declared' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.First', 'D365Bap.Tools.Second')]
    param()
    Get-First | Select-PSFObject -TypeName 'D365Bap.Tools.First'
    Get-Second | Select-PSFObject -TypeName 'D365Bap.Tools.Second'
}
'@

Assert-OutputType 'Multiple PSF types with one missing' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.First')]
    param()
    Get-First | Select-PSFObject -TypeName 'D365Bap.Tools.First'
    Get-Second | Select-PSFObject -TypeName 'D365Bap.Tools.Second'
}
'@ 1 @("does not declare 'D365Bap.Tools.Second'")

Assert-OutputType 'Module qualified Select-PSFObject' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.Example')]
    param()
    Get-Thing | PSFramework\Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@

Assert-OutputType 'Internal function is checked' @'
function Set-Fixture {
    param()
    Get-Thing
}
'@ 1 @('must declare [OutputType()]') -Directory 'd365bap.tools/internal/functions'

Assert-OutputType 'Internal PSF function is checked' @'
function Set-Fixture {
    [OutputType('D365Bap.Tools.Example')]
    param()
    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
'@ -Directory 'd365bap.tools/internal/functions'

Assert-OutputType 'Test files are exempt' @'
function Set-Fixture {
    param()
    Get-Thing
}
'@ -FileName 'Set-Fixture.Tests.ps1'


Assert-OutputType 'Outside the module' @'
function Set-Fixture {
    param()
    Get-Thing
}
'@ -Directory 'build'

Assert-OutputType 'Every top-level function is checked' @'
function Get-Helper {
    param()
    Get-Thing
}

function Set-Fixture {
    [OutputType([void])]
    param()
}
'@ 1 @('Get-Helper')

Assert-OutputType 'No parameter block' @'
function Set-Fixture {
    Get-Thing
}
'@ 1 @('must declare [OutputType()]')

Assert-OutputType 'Filename does not select the checked function' 'function Other { param() }' 1 @('Other')
Assert-OutputType 'Two missing declarations' 'function First { param() }; function Second { param() }' 2
Assert-OutputType 'Nested helper does not contaminate outer type' 'function Set-Fixture { [OutputType([void])] param(); function Helper { param(); $x | Select-PSFObject -TypeName "Other.Type" } }'
Assert-OutputType 'Attached qualified projection type is checked' 'function Set-Fixture { [OutputType([void])] param(); $x | PSFramework\Select-PSFObject -TypeName:"D365Bap.Tools.Example" }' 1 @('does not declare')
Assert-OutputType 'SDK folder remains outside declaration scope' 'function Other { param() }' -Directory 'd365bap.tools/internal/sdk'
Assert-OutputType 'Class methods are not module function declarations' 'class LocalFixture { [string] GetValue() { return "sample" } }; function Set-Fixture { [OutputType([void])] param() }'

Write-Output "Output type rule checks passed: $script:caseCount cases."
