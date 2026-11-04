<#
    .SYNOPSIS
        Ensures the CI module set is installed.

    .DESCRIPTION
        Installs missing modules from ModuleCacheRequirements.json after cache restore. Lint installs only analyzer pins. Base and generated also register the CI-only Az.Accounts stub so import skips the real Azure module.

    .PARAMETER Set
        'lint' (validate lint), 'base' (validate, build) or 'generated' (regen, freshness).
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet('lint', 'base', 'generated')]
	[string]$Set
)

$ErrorActionPreference = 'Stop'

$requirementsPath = Join-Path $PSScriptRoot 'ModuleCacheRequirements.json'
$requirements = Get-Content -LiteralPath $requirementsPath -Raw | ConvertFrom-Json
$modules = $requirements.$Set
if (-not $modules) { throw "Unknown module set '$Set' in $requirementsPath" }

if ($Set -in @('base', 'generated')) {
	$stubRoot = Join-Path $PSScriptRoot 'ci-stubs'
	$stubManifest = Join-Path $stubRoot 'Az.Accounts/99.0.0/Az.Accounts.psd1'
	if (-not (Test-Path -LiteralPath $stubManifest)) {
		throw "CI Az.Accounts stub missing at $stubManifest"
	}
	$parts = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ -and $_ -ne $stubRoot })
	$env:PSModulePath = (@($stubRoot) + $parts) -join [IO.Path]::PathSeparator
	if ($env:GITHUB_ENV) {
		Add-Content -LiteralPath $env:GITHUB_ENV -Value "PSModulePath=$($env:PSModulePath)" -Encoding utf8
	}
	Write-Host "Registered CI Az.Accounts stub from $stubRoot (version 99.0.0 wins over any restored real pin)."
}

$missing = 0
$galleryReady = $false
foreach ($entry in $modules) {
	$name = $entry.Name
	$version = $entry.Version
	$found = Get-Module -ListAvailable -Name $name |
	Where-Object { $_.Version -eq [version]$version } |
	Select-Object -First 1
	if ($found) {
		Write-Host "Present: $name $($found.Version)"
		continue
	}
	$missing++
	if (-not $galleryReady) {
		if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
			Register-PSRepository -Default
		}
		Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
		$galleryReady = $true
	}
	Write-Host "Installing $name $version..."
	Install-Module -Name $name -RequiredVersion $version -Scope CurrentUser -Force -SkipPublisherCheck
}

if ($missing -eq 0) {
	Write-Host "Module set '$Set' already satisfied ($($modules.Count) modules)."
}
else {
	Write-Host "Installed $missing missing module(s) for set '$Set'."
}
