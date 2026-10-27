<#
    .SYNOPSIS
        Ensures the CI module set is installed.

    .DESCRIPTION
        Installs any missing module from ModuleCacheRequirements.json at its pinned version. Runs after a restore-only cache step; a cache miss only makes the job slower.

    .PARAMETER Set
        'base' (validate, build) or 'generated' (regen, freshness).
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[ValidateSet('base', 'generated')]
	[string]$Set
)

$ErrorActionPreference = 'Stop'

$requirementsPath = Join-Path $PSScriptRoot 'ModuleCacheRequirements.json'
$requirements = Get-Content -LiteralPath $requirementsPath -Raw | ConvertFrom-Json
$modules = $requirements.$Set
if (-not $modules) { throw "Unknown module set '$Set' in $requirementsPath" }

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
