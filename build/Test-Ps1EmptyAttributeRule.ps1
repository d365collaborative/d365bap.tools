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
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1EmptyAttributeDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('empty-attribute-rule-' + [guid]::NewGuid().ToString('N') + '.ps1')
$script:caseCount = 0

function Assert-EmptyAttribute {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @())
	[IO.File]::WriteAllText($fixturePath, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $fixturePath
	$diagnostics = @(Get-Ps1EmptyAttributeDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$empty = @'
function Get-Fixture {
    param (
        [Parameter()]
        [string] $Name
    )
}
'@
Assert-EmptyAttribute 'Empty attribute' $empty 1 @('PSAvoidEmptyParameterAttribute', '-Name', '[Parameter()]')

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
