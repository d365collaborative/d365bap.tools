#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Formats staged PowerShell scripts.
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

. "$PSScriptRoot/../internal/Resolve-Ps1Path.ps1"
. "$PSScriptRoot/../internal/Invoke-Ps1Format.ps1"

$settingsPath = Resolve-Path (Join-Path $PSScriptRoot '..\internal\Ps1FormatSettings.psd1')

$before = @{}

foreach ($file in $files) {
	$before[$file] = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
}

Invoke-Ps1Format -Path $files -SettingsPath $settingsPath

$changed = 0

foreach ($file in $files) {
	$after = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash

	if ($after -ne $before[$file]) {
		Write-Output "  formatted: $file"
		$changed = 1
	}
}

exit $changed
