<#
.SYNOPSIS
    Checks exit codes after optional import probes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
function Get-AzContext { }
function Write-PSFMessage { param($Level, $Message) }
function az {
	if ($IsWindows) { & $env:ComSpec /c exit 1 }
	else { & /bin/sh -c 'exit 1' }
}

$initialExitCode = $global:LASTEXITCODE
try {
	foreach ($file in @('token-preload.ps1', 'finopsversion-preload.ps1')) {
		$source = Join-Path $root "d365bap.tools/internal/sdk/$file"
		foreach ($previousExitCode in @(0, 37)) {
			foreach ($nativeErrors in @($false, $true)) {
				$PSNativeCommandUseErrorActionPreference = $nativeErrors
				$global:LASTEXITCODE = $previousExitCode
				. $source
				if ($global:LASTEXITCODE -ne $previousExitCode) {
					throw "$file changed caller exit code $previousExitCode to $global:LASTEXITCODE (native errors: $nativeErrors)."
				}
			}
		}
	}
}
finally { $global:LASTEXITCODE = $initialExitCode }
Write-Host 'Both preloaders preserve successful and failed caller exit codes, including native command exceptions.'
