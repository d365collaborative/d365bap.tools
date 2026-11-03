#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks PowerShell scripts and help conventions.

.DESCRIPTION
    Runs the shared analyzer entry point: PSScriptAnalyzer plus repository
    rules. Shows every diagnostic and fails according to the shared policy
    in Ps1AnalyzerSettings.psd1. Parse errors always fail.
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

		if ($item -notmatch '\.(ps1|psm1|psd1)$') { continue }

		if (-not (Test-Path -LiteralPath $item)) { continue }

		(Resolve-Path -LiteralPath $item).Path
	}
)

if ($files.Count -eq 0) { exit 0 }

. "$PSScriptRoot/../internal/Invoke-Ps1Analysis.ps1"
$analyzer = New-Ps1Analyzer
$cacheSession = New-Ps1AnalysisCacheSession -Analyzer $analyzer

$results = @()
$failedFiles = @()

foreach ($p in $files) {
	$fileResult = Invoke-Ps1Analysis -Path $p `
		-Analyzer $analyzer `
		-AnalysisCache $cacheSession `
		-SkipCustomRules:($p -notmatch '\.ps1$')
	$results += @($fileResult.Diagnostics)

	if ($fileResult.Failed) {
		$failedFiles += $p
	}
}

Complete-Ps1AnalysisCacheSession -Session $cacheSession

if ($results.Count -gt 0) {
	$results |
	Format-Table -AutoSize `
		-Wrap |
	Out-String |
	Write-Host
}

if ($failedFiles.Count -gt 0) {
	Write-Output "$($failedFiles.Count) file(s) failed PSScriptAnalyzer or repository rules."
	exit 1
}

exit 0
