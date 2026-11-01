#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks PowerShell scripts and help conventions.

.DESCRIPTION
    Runs PSScriptAnalyzer plus repository rules. Shows warnings and
    errors, but fails only on errors.
#>
[CmdletBinding()]
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]] $Remaining
)

$ErrorActionPreference = 'Stop'

$files = @(
	foreach ($item in @($Remaining)) {
		if ([string]::IsNullOrWhiteSpace($item)) { continue }

		if ($item -match '^-') { continue }

		if ($item -notmatch '\.ps1$') { continue }

		if (-not (Test-Path -LiteralPath $item)) { continue }

		(Resolve-Path -LiteralPath $item).Path
	}
)

if ($files.Count -eq 0) { exit 0 }

$results = @()
. "$PSScriptRoot/../internal/Get-Ps1CommentDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1HelpDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1WildcardDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1EmptyAttributeDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1MandatoryDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1ParameterArgumentDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1ParameterPositionDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1ParameterSpacingDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1AttributeStackDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1TableFormatDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1ExcelOutputDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1AddMemberDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1AliasDiagnostic.ps1"
. "$PSScriptRoot/../internal/Get-Ps1AliasConfiguration.ps1"
. "$PSScriptRoot/../internal/Resolve-Ps1AliasCommand.ps1"
. "$PSScriptRoot/../internal/Get-Ps1CommentGroup.ps1"
. "$PSScriptRoot/../internal/Get-Ps1HelpSection.ps1"
. "$PSScriptRoot/../internal/Get-Ps1Analysis.ps1"
$worker = Get-Ps1AnalysisWorker

foreach ($p in $files) {
	$analysis = Get-Ps1Analysis -Path $p
	$results += Invoke-ScriptAnalyzer -Path $p -Recurse -Severity @('Error', 'Warning') -ExcludeRule 'PSAvoidUsingCmdletAliases' -ErrorAction Stop
	$results += @(Get-Ps1CommentDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1HelpDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1WildcardDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1EmptyAttributeDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1MandatoryDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1ParameterArgumentDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1ParameterPositionDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1ParameterSpacingDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1AttributeStackDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1TableFormatDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1ExcelOutputDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1AddMemberDiagnostic -Analysis $analysis)
	$results += @(Get-Ps1AliasDiagnostic -Analysis $analysis -Worker $worker)
}

if ($results.Count -gt 0) {
	$results | Format-Table -AutoSize -Wrap | Out-String | Write-Host
}

$errors = @($results | Where-Object { $_.Severity -eq 'Error' })

if ($errors.Count -gt 0) {
	Write-Output "$($errors.Count) PSScriptAnalyzer errors."
	exit 1
}

exit 0
