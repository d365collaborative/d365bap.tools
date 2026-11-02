<#
.SYNOPSIS
    Tests the command and parameter alias lint rules.

.DESCRIPTION
    Parses fixtures and checks that forbidden parameter alias declarations and
    forbidden alias or abbreviation usages fail through the shared analyzer,
    while allowlisted names pass. Command alias checks keep working.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/ps1-lint/internal/Invoke-Ps1Analysis.ps1"
$ruleId = 'Get-Ps1AliasDiagnostic'
if (@(Get-Ps1DiagnosticRule | Where-Object { $_.Id -eq $ruleId }).Count -ne 1) {
	throw "$ruleId is not registered in Get-Ps1DiagnosticRule."
}
$analyzer = New-Ps1Analyzer
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('alias-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Alias {
	param(
		[string] $Label,
		[string] $Source,
		[int] $Expected = 0,
		[string[]] $ExpectedText = @(),
		[string[]] $AllowedCommandAliases = @(),
		[string[]] $AllowedParameterAliases = @(),
		[string] $Configuration
	)

	$caseRoot = Join-Path $fixtureRoot ([guid]::NewGuid().ToString('N'))
	$folder = Join-Path $caseRoot 'build/fixtures'
	$null = New-Item -ItemType Directory -Path $folder -Force
	if (-not $PSBoundParameters.ContainsKey('Configuration')) {
		$hashConfiguration = [ordered]@{
			allowedCommandAliases   = @($AllowedCommandAliases)
			allowedParameterAliases = @($AllowedParameterAliases)
		}
		$Configuration = ConvertTo-Json -InputObject $hashConfiguration
	}
	[IO.File]::WriteAllText((Join-Path $caseRoot 'ps1-lint.json'), $Configuration)
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))

	$result = Invoke-Ps1Analysis -Path $path -Analyzer $analyzer
	$colDiagnostics = @($result.Diagnostics | Where-Object {
			$_.RuleName -in @('PSAvoidParameterAliases', 'PSAvoidCommandAliases', 'PSAliasConfiguration')
		})
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected alias diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	foreach ($itemDiagnostic in $colDiagnostics) {
		if ($itemDiagnostic.Severity -ne 'Error') { throw "${Label}: expected Error severity, got $($itemDiagnostic.Severity)." }
	}
	if ($Expected -gt 0 -and -not $result.Failed) { throw "${Label}: the shared analyzer did not fail the forbidden fixture." }
	if ($Expected -eq 0 -and $result.Failed) {
		throw "${Label}: the shared analyzer failed the allowed fixture: $(@($result.Diagnostics.Message) -join ' ')"
	}
	$script:caseCount++
}

Assert-Alias 'Forbidden parameter alias declaration' @'
function Get-Fixture {
    param (
        [Alias('Forbidden')]
        [string] $Name
    )
}
'@ -Expected 1 -ExpectedText @('PSAvoidParameterAliases', 'Do not declare parameter aliases', "'Name'")

Assert-Alias 'Allowed parameter alias declaration' @'
function Get-Fixture {
    param (
        [Alias('Forbidden')]
        [string] $Name
    )
}
'@ -AllowedParameterAliases @('Forbidden')

Assert-Alias 'Allowed parameter alias declaration ignores case' @'
function Get-Fixture {
    param (
        [Alias('Forbidden')]
        [string] $Name
    )
}
'@ -AllowedParameterAliases @('forbidden')

Assert-Alias 'Parameter without an alias' @'
function Get-Fixture {
    param (
        [string] $Name
    )
}
'@

Assert-Alias 'Forbidden parameter alias usage' @'
function Get-Fixture {
    param (
        [Alias('Forbidden')]
        [string] $Name
    )

    $Name
}

Get-Fixture -Forbidden 'value'
'@ -Expected 2 -ExpectedText @('Do not declare parameter aliases', "Do not use parameter alias or abbreviation '-Forbidden'")

Assert-Alias 'Allowed parameter alias usage' @'
function Get-Fixture {
    param (
        [Alias('Forbidden')]
        [string] $Name
    )

    $Name
}

Get-Fixture -Forbidden 'value'
'@ -AllowedParameterAliases @('Forbidden')

Assert-Alias 'Forbidden cmdlet parameter alias usage' @'
Get-ChildItem -Path . -ea Stop
'@ -Expected 1 -ExpectedText @("Do not use parameter alias or abbreviation '-ea'", 'ErrorAction')

Assert-Alias 'Allowed cmdlet parameter alias usage' @'
Get-ChildItem -Path . -ea Stop
'@ -AllowedParameterAliases @('ea')

Assert-Alias 'Forbidden parameter abbreviation' @'
Get-ChildItem -Path . | Select-Object -Fir 1
'@ -Expected 1 -ExpectedText @("Do not use parameter alias or abbreviation '-Fir'", 'First')

Assert-Alias 'Allowed parameter abbreviation' @'
Get-ChildItem -Path . | Select-Object -Fir 1
'@ -AllowedParameterAliases @('Fir')

Assert-Alias 'Forbidden command alias declaration' @'
Set-Alias -Name gci -Value Get-ChildItem
'@ -Expected 1 -ExpectedText @('PSAvoidCommandAliases', 'Do not declare command aliases')

Assert-Alias 'Allowed command alias declaration' @'
Set-Alias -Name gci -Value Get-ChildItem
'@ -AllowedCommandAliases @('gci')

Assert-Alias 'Forbidden command alias usage' @'
gci -Path .
'@ -Expected 1 -ExpectedText @("Do not use command alias 'gci'", 'Get-ChildItem')

Assert-Alias 'Allowed command alias usage' @'
gci -Path .
'@ -AllowedCommandAliases @('gci')

Assert-Alias 'Legacy rules configuration is rejected' @'
function Get-Fixture {
    param (
        [string] $Name
    )
}
'@ -Expected 1 -ExpectedText @('PSAliasConfiguration', 'The rules object is no longer supported') -Configuration '{"rules":{"PSAvoidParameterAliases":false}}'

Assert-Alias 'Non-array parameter allowlist is rejected' @'
function Get-Fixture {
    param (
        [string] $Name
    )
}
'@ -Expected 1 -ExpectedText @('PSAliasConfiguration', 'must be an array of nonempty strings') -Configuration '{"allowedParameterAliases":"PpacEnvId"}'

Write-Output "Alias rule checks passed: $script:caseCount cases."
