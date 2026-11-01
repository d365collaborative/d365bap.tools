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
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ParameterContractDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('parameter-argument-rule-' + [guid]::NewGuid().ToString('N') + '.ps1')
$script:caseCount = 0

function Assert-ParameterArgument {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @())
	[IO.File]::WriteAllText($fixturePath, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $fixturePath
	$diagnostics = @(Get-Ps1ParameterContractDiagnostic -Analysis $analysis | Where-Object { $_.RuleName -eq 'PSAvoidRedundantParameterAttribute' -and $_.Message -like 'Remove the redundant*' })
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
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
