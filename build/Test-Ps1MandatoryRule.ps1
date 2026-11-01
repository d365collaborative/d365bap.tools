<#
.SYNOPSIS
    Tests the mandatory parameter validation lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that mandatory string parameters without
    a default value require a ValidateNotNullOrEmpty attribute.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ParameterContractDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('mandatory-rule-' + [guid]::NewGuid().ToString('N') + '.ps1')
$script:caseCount = 0

function Assert-Mandatory {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Rule = 'PSUseValidateNotNullOrEmpty')
	[IO.File]::WriteAllText($fixturePath, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $fixturePath
	$colDiagnostics = @(Get-Ps1ParameterContractDiagnostic -Analysis $analysis | Where-Object RuleName -eq $Rule)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

$mandatory = @'
function Get-Fixture {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )
}
'@
Assert-Mandatory 'Mandatory string without validation' $mandatory 1 @('PSUseValidateNotNullOrEmpty', '-Name', '[ValidateNotNullOrEmpty()]')

$validated = $mandatory.Replace('[Parameter(Mandatory = $true)]', "[Parameter(Mandatory = `$true)]`n        [ValidateNotNullOrEmpty()]")
Assert-Mandatory 'Mandatory string with validation' $validated

$validatedFirst = $mandatory.Replace('[Parameter(Mandatory = $true)]', "[ValidateNotNullOrEmpty()]`n        [Parameter(Mandatory = `$true)]")
Assert-Mandatory 'Validation before parameter attribute' $validatedFirst

$shorthand = $mandatory.Replace('[Parameter(Mandatory = $true)]', '[Parameter(Mandatory)]')
Assert-Mandatory 'Shorthand mandatory' $shorthand 1 @('-Name')
Assert-Mandatory 'Shorthand mandatory is flagged' $shorthand -Rule 'PSAvoidShorthandMandatory' -Expected 1 -ExpectedText @('PSAvoidShorthandMandatory', '-Name', 'Mandatory = $true')
Assert-Mandatory 'Explicit form is not shorthand' $mandatory -Rule 'PSAvoidShorthandMandatory'
Assert-Mandatory 'Shorthand with parameter set' ($mandatory.Replace('[Parameter(Mandatory = $true)]', "[Parameter(Mandatory, ParameterSetName = 'Default')]")) -Rule 'PSAvoidShorthandMandatory' -Expected 1
Assert-Mandatory 'Shorthand with false value' ($mandatory.Replace('Mandatory = $true', 'Mandatory = $false')) -Rule 'PSAvoidShorthandMandatory'
Assert-Mandatory 'Script-level shorthand' @'
param (
    [Parameter(Mandatory)]
    [string] $Name
)
'@ -Rule 'PSAvoidShorthandMandatory' -Expected 1
Assert-Mandatory 'Multiple shorthand parameters' @'
function Get-Fixture {
    param (
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Kind
    )
}
'@ -Rule 'PSAvoidShorthandMandatory' -Expected 2 @('-Name', '-Kind')

Assert-Mandatory 'Mandatory false' ($mandatory.Replace('Mandatory = $true', 'Mandatory = $false'))

Assert-Mandatory 'Dynamic mandatory value' ($mandatory.Replace('Mandatory = $true', 'Mandatory = $script:isMandatory'))

Assert-Mandatory 'String default' ($mandatory.Replace('[string] $Name', '[string] $Name = "demo"'))

Assert-Mandatory 'Empty string default' ($mandatory.Replace('[string] $Name', '[string] $Name = ""'))

Assert-Mandatory 'Null default' ($mandatory.Replace('[string] $Name', '[string] $Name = $null'))

Assert-Mandatory 'Environment default' ($mandatory.Replace('[string] $Name', '[string] $Name = $env:NAME'))

Assert-Mandatory 'Wildcard default' ($mandatory.Replace('[string] $Name', '[string] $Name = "*"'))

Assert-Mandatory 'String array without validation' ($mandatory.Replace('[string] $Name', '[string[]] $Name')) -Expected 1

Assert-Mandatory 'Integer parameter' ($mandatory.Replace('[string] $Name', '[int] $Name'))

Assert-Mandatory 'Switch parameter' ($mandatory.Replace('[string] $Name', '[switch] $Name'))

Assert-Mandatory 'Object parameter' ($mandatory.Replace('[string] $Name', '[object] $Name'))

Assert-Mandatory 'Non-mandatory string' ($mandatory.Replace('[Parameter(Mandatory = $true)]', '[Parameter()]'))

Assert-Mandatory 'Only ValidateNotNull' ($mandatory.Replace('[Parameter(Mandatory = $true)]', "[Parameter(Mandatory = `$true)]`n        [ValidateNotNull()]")) -Expected 1

Assert-Mandatory 'Multiple parameter sets' @'
function Get-Fixture {
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [Parameter(Mandatory = $true, ParameterSetName = "NextLink")]
        [string] $Name
    )
}
'@ -Expected 1 @('-Name')

Assert-Mandatory 'Script-level parameter' @'
param (
    [Parameter(Mandatory = $true)]
    [string] $Name
)
'@ -Expected 1

Assert-Mandatory 'Multiple parameters' @'
function Get-Fixture {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Kind,

        [Parameter(Mandatory = $true)]
        [string] $Label = "demo"
    )
}
'@ -Expected 2 @('-Name', '-Kind')

Write-Output "Mandatory rule checks passed: $script:caseCount cases."
