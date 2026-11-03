<#
.SYNOPSIS
    Tests the explicit Select-Object property lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that Select-Object names its projection
    explicitly. Simple property lists and non-projection shapes stay allowed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/testing/Assert-Ps1RuleCase.ps1"
foreach ($itemPath in Get-Ps1RuleAnalysisScriptPath -BuildRoot $PSScriptRoot -ScriptName @(
		'Get-Ps1CommentGroup'
		'Get-Ps1HelpSection'
		'Get-Ps1Analysis'
		'Get-Ps1ComplexArrayElementDiagnostic'
		'Get-Ps1StandardSelectObjectDiagnostic'
	)) {
	. $itemPath
}
$fixtureRoot = Initialize-Ps1RuleFixtureRoot -NamePrefix 'select-object-property-rule'
$script:caseCount = 0

function Assert-SelectObjectProperty {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string] $Directory = 'd365bap.tools/functions',
		[string] $FileName = 'Get-Fixture.ps1'
	)
	Assert-Ps1RuleCase -FixtureRoot $fixtureRoot `
		-DiagnosticCommand 'Get-Ps1StandardSelectObjectDiagnostic' `
		-Label $Label `
		-Source $Source `
		-Expected $Expected `
		-ExpectedText $ExpectedText `
		-Directory $Directory `
		-FileName $FileName
}

Assert-SelectObjectProperty 'Issue example' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1 @('PSUseStandardSelectObject', '-Property')

Assert-SelectObjectProperty 'Single calculated property' @'
function Get-Fixture {
    $item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Calculated property after a simple name' @'
function Get-Fixture {
    $item | Select-Object Name, @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Calculated property before a trailing parameter' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } } -First 1
}
'@ -Expected 1

Assert-SelectObjectProperty 'Explicit Property parameter' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1 @('own line')

Assert-SelectObjectProperty 'Explicit abbreviated Property parameter' @'
function Get-Fixture {
    $item | Select-Object -Prop @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Simple property list' @'
function Get-Fixture {
    $item | Select-Object Name, Id
}
'@ -Expected 1

Assert-SelectObjectProperty 'Wildcard only' @'
function Get-Fixture {
    $item | Select-Object *
}
'@ -Expected 1

Assert-SelectObjectProperty 'First only' @'
function Get-Fixture {
    $item | Select-Object -First 1
}
'@

Assert-SelectObjectProperty 'ExpandProperty only' @'
function Get-Fixture {
    $item | Select-Object -ExpandProperty Name
}
'@

Assert-SelectObjectProperty 'Splat is not resolved' @'
function Get-Fixture {
    $item | Select-Object @params
}
'@ -Expected 1

Assert-SelectObjectProperty 'Hashtable in a string' @'
function Get-Fixture {
    $text = 'Select-Object *, @{ Name = ''Kind'' }'
    $text
}
'@

Assert-SelectObjectProperty 'Hashtable in a comment' @'
function Get-Fixture {
    # Select-Object *, @{ Name = 'Kind' }
    Get-Thing
}
'@

Assert-SelectObjectProperty 'Internal module code is checked' @'
function Get-Fixture {
    $item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-SelectObjectProperty 'Build scripts are exempt' @'
$item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
'@ -Directory 'build/scripts'

Assert-SelectObjectProperty 'Tepp fixtures are exempt' @'
$item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-SelectObjectProperty 'Test files are exempt' @'
$item | Select-Object @{ Name = 'Kind'; Expression = { $kind } }
'@ -FileName 'Get-Fixture.Tests.ps1'

Assert-SelectObjectProperty 'Variable projection' '$item | Select-Object -Property $properties' -Expected 1 @('Unsupported')
Assert-SelectObjectProperty 'Qualified positional projection' '$item | Microsoft.PowerShell.Utility\Select-Object Name' -Expected 1
Assert-SelectObjectProperty 'Short calculated keys' '$item | Select-Object -Property @{ N = "Name"; E = { $_.Name } }' -Expected 1
Assert-SelectObjectProperty 'Non-scriptblock expression' '$item | Select-Object -Property @{ Name = "Name"; Expression = "Name" }' -Expected 1
Assert-SelectObjectProperty 'Explicit simple properties' '$item | Select-Object -Property Name, Id'
Assert-SelectObjectProperty 'Skip and Last' '$item | Select-Object -Skip 1 -Last 2'

Assert-SelectObjectProperty 'Scriptblock pipeline is not a scriptblock value' '$item | Select-Object -Property @{ Name = "Name"; Expression = { $_.Name } | Out-String }' -Expected 1
Assert-SelectObjectProperty 'Calculated keys have fixed order' '$item | Select-Object -Property @{ Expression = { $_.Name }; Name = "Name" }' -Expected 1
Assert-SelectObjectProperty 'Duplicate property cannot hide a variable' '$item | Select-Object -Property $properties -Property Name' -Expected 1
Assert-SelectObjectProperty 'Common parameters with projection' '$item | Select-Object -Property Name -ErrorAction Stop -Verbose'
Assert-SelectObjectProperty 'Missing selection argument' '$item | Select-Object -First -Property Name' -Expected 1

$combinedSource = '$item | Select-Object -Property @{ Name = "A"; Expression = { $_.A } }, @{ Name = "B"; Expression = { $_.B } }'
$combinedPath = Join-Path $fixtureRoot 'd365bap.tools/functions/Get-Fixture.ps1'
[IO.File]::WriteAllText($combinedPath, $combinedSource)
$combinedAnalysis = Get-Ps1Analysis -Path $combinedPath
$combinedDiagnostics = @(
	Get-Ps1StandardSelectObjectDiagnostic $combinedAnalysis
	Get-Ps1ComplexArrayElementDiagnostic $combinedAnalysis
)
if ($combinedDiagnostics.Count -ne 1 -or $combinedDiagnostics[0].RuleName -ne 'PSUseStandardSelectObject') {
	throw "Projection layout must have one owner: $($combinedDiagnostics.RuleName -join ', ')"
}

Assert-SelectObjectProperty 'Calculated properties on one line' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1 @('PSUseStandardSelectObject', 'own line')

Assert-SelectObjectProperty 'Simple name and calculated property on one line' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Calculated property on the next line' @'
function Get-Fixture {
    $item | Select-Object -Property *
, @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-SelectObjectProperty 'Single calculated property on a continuation line' @'
function Get-Fixture {
    $item | Select-Object `
    -Property @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-SelectObjectProperty 'Second calculated property on the first line' @'
function Get-Fixture {
    $item | Select-Object -Property *,
        @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Module-qualified command' @'
function Get-Fixture {
    $item | Microsoft.PowerShell.Utility\Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'One calculated property per line' @'
function Get-Fixture {
    $item | Select-Object -Property *,
        @{ Name = 'Kind'; Expression = { $kind } },
        @{ Name = 'Source'; Expression = { $source } }
}
'@

Assert-SelectObjectProperty 'One calculated property per line with a parameter after it' @'
function Get-Fixture {
    $item | Select-Object -Property *,
        @{ Name = 'Kind'; Expression = { $kind } },
        @{ Name = 'Source'; Expression = { $source } } -First 1
}
'@

Assert-SelectObjectProperty 'Single calculated property' @'
function Get-Fixture {
    $item | Select-Object -Property @{ Name = 'Kind'; Expression = { $kind } }
}
'@

Assert-SelectObjectProperty 'Simple property list' @'
function Get-Fixture {
    $item | Select-Object -Property Name, DisplayName
}
'@

Assert-SelectObjectProperty 'Splat' @'
function Get-Fixture {
    $hashSelect = @{
        Property = @(
            @{ Name = 'Kind'; Expression = { $kind } }
            @{ Name = 'Source'; Expression = { $source } }
        )
    }
    $item | Select-Object @hashSelect
}
'@ -Expected 1 @('Unsupported')

Assert-SelectObjectProperty 'Calculated property without -Property' @'
function Get-Fixture {
    $item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1

Assert-SelectObjectProperty 'Select-Object in a string' @'
function Get-Fixture {
    $text = "Select-Object -Property *, @{ Name = 'Kind'; Expression = { `$kind } }"
    $text
}
'@

Assert-SelectObjectProperty 'Where-Object is not Select-Object' @'
function Get-Fixture {
    $item | Where-Object { $_.Name }
}
'@

Assert-SelectObjectProperty 'Internal module code is checked' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-SelectObjectProperty 'Build scripts are exempt' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Directory 'build/scripts'

Assert-SelectObjectProperty 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-SelectObjectProperty 'Test files are exempt' @'
function Get-Fixture {
    $item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Assert-SelectObjectProperty 'Abbreviated parameter still checks layout' '$item | Select-Object -Prop @{ Name = "N"; Expression = { 1 } }, Name' -Expected 1
Assert-SelectObjectProperty 'Simple property after calculated property' '$item | Select-Object -Property @{ Name = "N"; Expression = { 1 } }, Name' -Expected 1
Assert-SelectObjectProperty 'Other qualified command ignored' '$item | Other.Module\Select-Object -Property *, @{ Name = "N"; Expression = { 1 } }'


Write-Output "Select-Object property rule checks passed: $script:caseCount cases."
