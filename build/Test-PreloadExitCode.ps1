<#
.SYNOPSIS
    Checks exit codes after optional import probes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$pwsh = (Get-Process -Id $PID).Path
$driver = @'
param($Source, [int]$PreviousExitCode, [bool]$NativeErrors)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $NativeErrors
$script:probeCount = 0
function Get-AzContext { }
function Write-PSFMessage { param($Level, $Message) Write-Host $Message }
function Start-Job { throw 'An unauthenticated import must not start a preload job.' }
function az {
    $script:probeCount++
    & (Get-Process -Id $PID).Path -NoProfile -NonInteractive -Command 'exit 1'
}
$global:LASTEXITCODE = $PreviousExitCode
. $Source
if ($script:probeCount -ne 1) { throw "Expected one login probe, got $script:probeCount" }
Write-Host "Caller exit code: $global:LASTEXITCODE"
if (Test-Path -LiteralPath variable:\LASTEXITCODE) { exit $LASTEXITCODE }
'@

foreach ($file in @('token-preload.ps1', 'finopsversion-preload.ps1')) {
	$source = Join-Path $root "d365bap.tools/internal/sdk/$file"
	foreach ($previousExitCode in @(0, 37)) {
		foreach ($nativeErrors in @($false, $true)) {
			$sourceLiteral = $source.Replace("'", "''")
			$command = "& { $driver } '$sourceLiteral' $previousExitCode `$$nativeErrors"
			$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
			$output = @(& $pwsh -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | ForEach-Object { "$_" }) -join "`n"
			$actual = $LASTEXITCODE
			if ($actual -ne $previousExitCode -or $output -notmatch "Caller exit code: $previousExitCode") {
				throw "$file changed caller exit code $previousExitCode to $actual (native errors: $nativeErrors): $output"
			}
		}
	}
}
Write-Host 'Both preloaders preserve successful and failed caller exit codes, including native command exceptions.'
