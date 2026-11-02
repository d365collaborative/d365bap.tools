#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Formats and analyzes files in one batch process.

.DESCRIPTION
    Runs the formatter and the analyzer in one pwsh process. Files are read in
    bounded chunks and every file has its own try/catch, so one failure does
    not stop the rest. Analysis checks the formatted text.

.PARAMETER CheckOnly
    Never write a file. Formatting drift still fails the run. Also selected by
    PS1_LINT_CHECK_ONLY.

.PARAMETER BatchSize
    Number of files held in memory at once.

    Default: 32.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
	[switch] $CheckOnly,
	[ValidateRange(1, 512)]
	[int] $BatchSize = 32,
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]] $Remaining
)

$ErrorActionPreference = 'Stop'

if (-not $CheckOnly -and $env:PS1_LINT_CHECK_ONLY -match '^(1|true|yes)$') {
	$CheckOnly = $true
}

$files = @(
	foreach ($item in @($Remaining)) {
		if ([string]::IsNullOrWhiteSpace($item)) { continue }

		if ($item -match '^-') { continue }

		if ($item -notmatch '\.(ps1|psm1|psd1)$') { continue }

		if (-not (Test-Path -LiteralPath $item `
					-PathType Leaf)) { continue }

		(Resolve-Path -LiteralPath $item).Path
	}
)

if ($files.Count -eq 0) { exit 0 }

. "$PSScriptRoot/../internal/Invoke-Ps1LintBatch.ps1"

try {
	$objResult = Invoke-Ps1LintBatch -Path $files `
		-CheckOnly:$CheckOnly `
		-BatchSize $BatchSize
}
catch {
	Write-Host "  lint batch failed: $($_.Exception.Message)"
	exit 1
}

if ($objResult.FormatFailed -or $objResult.AnalysisFailed) {
	exit 1
}

exit 0
