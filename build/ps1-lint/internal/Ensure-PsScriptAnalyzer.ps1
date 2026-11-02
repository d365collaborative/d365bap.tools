. "$PSScriptRoot/Import-Ps1Analyzer.ps1"

function Ensure-PsScriptAnalyzer {
	<#
		.SYNOPSIS
			Ensures the pinned PSScriptAnalyzer version is available.

		.DESCRIPTION
			Returns true when the requested module is present. Otherwise it
			installs that exact build for CurrentUser and returns false when the
			install fails.

		.PARAMETER Version
			The module version to use.

			Default: the pin in Ps1AnalyzerSettings.psd1.

		.EXAMPLE
			PS C:\> Ensure-PsScriptAnalyzer

			It returns true once the pinned analyzer is importable.
			It will use -Version, which defaults to the settings pin.
	#>
	[CmdletBinding()]
	param(
		[string] $Version
	)

	if ([string]::IsNullOrWhiteSpace($Version)) {
		$Version = "$(Get-Ps1PinnedAnalyzerVersion)"
	}

	$targetVersion = [version] $Version
	$colInstalled = @(Get-Module -Name PSScriptAnalyzer `
			-ListAvailable `
			-ErrorAction SilentlyContinue |
		Where-Object { $_.Version -eq $targetVersion })
	if ($colInstalled.Count -gt 0) { $true; return }

	try {
		$repo = Get-PSRepository -Name PSGallery `
			-ErrorAction Stop
		if ($repo.InstallationPolicy -ne 'Trusted') {
			Set-PSRepository -Name PSGallery `
				-InstallationPolicy Trusted `
				-ErrorAction Stop > $null
		}
	}
	catch {
		$false; return
	}

	if (-not (Get-PackageProvider -Name NuGet `
				-ListAvailable `
				-ErrorAction SilentlyContinue)) {
		Install-PackageProvider -Name NuGet `
			-Force `
			-Scope CurrentUser `
			-ErrorAction SilentlyContinue > $null
	}

	$ProgressPreference = 'SilentlyContinue'

	Install-Module -Name PSScriptAnalyzer `
		-RequiredVersion $Version `
		-Scope CurrentUser `
		-Force `
		-SkipPublisherCheck `
		-AllowClobber `
		-ErrorAction SilentlyContinue > $null

	@(Get-Module -Name PSScriptAnalyzer `
			-ListAvailable `
			-ErrorAction SilentlyContinue |
		Where-Object { $_.Version -eq $targetVersion }).Count -gt 0
}
