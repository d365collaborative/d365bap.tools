#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Prepares modules for PowerShell worker hooks.

.DESCRIPTION
    Installs PSScriptAnalyzer silently in CurrentUser scope before
    PowerShell worker hooks run. Existing installations are reused.
#>
[CmdletBinding()]
param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]] $Remaining
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../internal/Ensure-PsScriptAnalyzer.ps1"

if (-not (Ensure-PsScriptAnalyzer)) {
	Write-Output '  PSScriptAnalyzer is required but could not be installed.'
	exit 1
}

exit 0
