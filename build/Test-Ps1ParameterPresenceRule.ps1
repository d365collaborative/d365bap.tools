<#
.SYNOPSIS
    Tests explicit parameter presence syntax.

.DESCRIPTION
    Preserves value, presence, and parameter-set decisions while enforcing
    ContainsKey spelling and declared keys where statically known.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ExplicitParameterPresenceDiagnostic'
		'Get-Ps1ParameterContractDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'direct-parameter-rule'
$script:caseCount = 0

function Assert-ParameterPresence {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1ExplicitParameterPresenceDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-ParameterPresence 'Valid checks' @'
function Get-Fixture { [CmdletBinding()] param([Alias('Other')][string] $Name) $PSBoundParameters.ContainsKey('Name'); $PSBoundParameters.ContainsKey($key); $PSCmdlet.ParameterSetName }
'@
Assert-ParameterPresence 'Method' @'
function Get-Fixture { param([string] $Name) $PSBoundParameters.Contains('Name') }
'@ -Expected 1 -ExpectedText @('PSUseExplicitParameterPresenceCheck', "ContainsKey('Name')")
Assert-ParameterPresence 'Alias' @'
function Get-Fixture { param([Alias('Other')][string] $Name) $PSBoundParameters.ContainsKey('Other') }
'@ -Expected 1 -ExpectedText @('declared name', "ContainsKey('Name')")
Assert-ParameterPresence 'Inline alias key' "function Get-Fixture ([Alias('Other')][string] `$Name) { `$PSBoundParameters.ContainsKey('Other') }" -Expected 1
Assert-ParameterPresence 'Unknown common and dynamic keys' "function Get-Fixture { [CmdletBinding()] param(); `$PSBoundParameters.ContainsKey('Verbose'); `$PSBoundParameters.ContainsKey('DynamicName') }"
Assert-ParameterPresence 'Dynamic method spelling' 'function Get-Fixture { param(); $PSBoundParameters.Contains($key) }' -Expected 1 @('ContainsKey($key)')
Assert-ParameterPresence 'Nested owner alias isolation' "function Outer { param([Alias('Other')][string] `$Name); function Inner { param([string] `$Other); `$PSBoundParameters.ContainsKey('Other') } }"
Assert-ParameterPresence 'Outside scope' "function Get-Fixture { param(); `$PSBoundParameters.Contains('Name') }" -Directory build

function Get-PresenceFixture {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param([object] $Value = 'default', [Parameter(ParameterSetName = 'Selected')][switch] $Select)
	[pscustomobject]@{ Supplied = $PSBoundParameters.ContainsKey('Value'); Value = $Value; Set = $PSCmdlet.ParameterSetName }
}
foreach ($case in @(
		@{ Args = @{}; Supplied = $false; Value = 'default'; Set = 'Default' },
		@{ Args = @{ Value = $false }; Supplied = $true; Value = $false; Set = 'Default' },
		@{ Args = @{ Value = 0 }; Supplied = $true; Value = 0; Set = 'Default' },
		@{ Args = @{ Value = '' }; Supplied = $true; Value = ''; Set = 'Default' },
		@{ Args = @{ Value = $null }; Supplied = $true; Value = $null; Set = 'Default' },
		@{ Args = @{ Select = $true }; Supplied = $false; Value = 'default'; Set = 'Selected' }
	)) {
	$arguments = $case.Args
	$result = Get-PresenceFixture @arguments
	if ($result.Supplied -ne $case.Supplied -or $result.Value -cne $case.Value -or $result.Set -ne $case.Set) { throw 'Runtime presence case failed' }
	$script:caseCount++
}
Write-Output "Runtime and syntax checks passed: $script:caseCount cases."

$presenceSource = "function Get-Fixture { param([SupportsWildcards()][string] `$Name = '*'); `$PSBoundParameters.ContainsKey('Name') }"
$presencePath = Join-Path $fixtureRoot 'd365bap.tools/functions/Get-Fixture.ps1'
[IO.File]::WriteAllText($presencePath, $presenceSource)
$presenceAnalysis = Get-Ps1Analysis -Path $presencePath
$combinedDiagnostics = @(Get-Ps1ExplicitParameterPresenceDiagnostic $presenceAnalysis) + @(Get-Ps1ParameterContractDiagnostic $presenceAnalysis)
if ($combinedDiagnostics.Count -ne 0) { throw "Wildcard presence must pass both owners: $($combinedDiagnostics.Message -join '; ')" }

$aliasPresenceFixture = [scriptblock]::Create('param([Alias(''Other'')][string] $Name) $PSBoundParameters.ContainsKey(''Name'') -and -not $PSBoundParameters.ContainsKey(''Other'')')
if (-not (& $aliasPresenceFixture -Other sample)) { throw 'Bound dictionary must use the declared key for alias input.' }
