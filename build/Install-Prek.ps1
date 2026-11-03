<#
    .SYNOPSIS
        Restores or installs the pinned prek executable.

    .DESCRIPTION
        Runs after the restore-only prek cache step. The restored executable must report exactly the pinned release. Otherwise it is replaced by a fresh pip install of the same pin. If the release still does not match, the step fails.

    .PARAMETER Version
        Exact prek version to require.

        Default: the prek pin in ToolCacheRequirements.json.

    .PARAMETER TargetPath
        Directory that holds the pip --target installation.

        Default: <RUNNER_TEMP>/prek.

    .PARAMETER PrekPath
        Executable to verify.

        Default: <TargetPath>/bin/prek.exe.

    .PARAMETER PythonExecutable
        Python used for pip.

        Default: python.
#>
[CmdletBinding()]
param(
	[string]$Version,
	[string]$TargetPath,
	[string]$PrekPath,
	[string]$PythonExecutable = 'python'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Version)) {
	$requirementsPath = Join-Path $PSScriptRoot 'ToolCacheRequirements.json'
	$requirements = Get-Content -LiteralPath $requirementsPath -Raw | ConvertFrom-Json
	$Version = [string]$requirements.prek
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
	throw "The prek pin must be an exact version, got '$Version'."
}
if ([string]::IsNullOrWhiteSpace($TargetPath)) {
	$tempRoot = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
	$TargetPath = Join-Path $tempRoot 'prek'
}
if ([string]::IsNullOrWhiteSpace($PrekPath)) {
	$PrekPath = Join-Path (Join-Path $TargetPath 'bin') 'prek.exe'
}

function Get-PrekReport {
	param([string]$Path)
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		[pscustomobject]@{ Present = $false; Version = $null; ExitCode = $null }
		return
	}
	$colOutput = @(& $Path --version 2>&1 | ForEach-Object { "$_" })
	$exitCode = $LASTEXITCODE
	$match = [regex]::Match(($colOutput -join "`n"), '(?m)^prek\s+(\d+\.\d+\.\d+)(?:\s|$)')
	[pscustomobject]@{
		Present  = $true
		Version  = if ($match.Success) { $match.Groups[1].Value } else { $null }
		ExitCode = $exitCode
	}
}

$report = Get-PrekReport -Path $PrekPath
if ($report.Present -and $report.ExitCode -eq 0 -and $report.Version -ceq $Version) {
	Write-Host "Restored pinned prek $Version from '$PrekPath'."
	return
}

if ($report.Present) {
	Write-Host "Restored prek reports version '$($report.Version)' (exit $($report.ExitCode)) instead of $Version; reinstalling the pin."
}
else {
	Write-Host "Pinned prek $Version was not restored to '$PrekPath'; installing the pin."
}

if (Test-Path -LiteralPath $TargetPath) {
	Remove-Item -LiteralPath $TargetPath -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $TargetPath -Force

& $PythonExecutable -m pip install --disable-pip-version-check --no-input --target $TargetPath "prek==$Version"
if ($LASTEXITCODE -ne 0) {
	throw "pip install prek==$Version failed with exit code $LASTEXITCODE."
}

$report = Get-PrekReport -Path $PrekPath
if (-not $report.Present -or $report.ExitCode -ne 0 -or $report.Version -cne $Version) {
	$observed = if ($report.Present) { "version '$($report.Version)' with exit code $($report.ExitCode)" } else { 'no executable' }
	throw "The pinned prek $Version could not be produced at '$PrekPath' ($observed). Refusing to fall back to another version."
}

Write-Host "Installed pinned prek $Version at '$PrekPath'."
