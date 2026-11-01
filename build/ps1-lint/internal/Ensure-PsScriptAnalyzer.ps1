function Ensure-PsScriptAnalyzer {
	<#
		.SYNOPSIS
			Ensures the pinned PSScriptAnalyzer version is available.

		.DESCRIPTION
			Returns true when the requested module is available. Otherwise
			installs it silently for CurrentUser. Returns false when installation
			fails or the module is still unavailable.

		.PARAMETER Version
			The module version to use.

			Default: 1.25.0

		.EXAMPLE
			PS C:\> Ensure-PsScriptAnalyzer

			Returns $true once PSScriptAnalyzer is importable.
			It will use -Version 1.25.0 by default.
	#>
	[CmdletBinding()]
	param(
		[ValidateNotNullOrEmpty()]
		[string] $Version = '1.25.0'
	)

	$targetVersion = [version] $Version
	$colInstalled = @(Get-Module -Name PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue |
		Where-Object { $_.Version -eq $targetVersion })
	if ($colInstalled.Count -gt 0) { $true; return }

	try {
		$repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
		if ($repo.InstallationPolicy -ne 'Trusted') {
			Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop | Out-Null
		}
	}
	catch {
		$false; return
	}

	if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
		$null = Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue
	}

	$ProgressPreference = 'SilentlyContinue'

	$null = Install-Module -Name PSScriptAnalyzer -RequiredVersion $Version -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -ErrorAction SilentlyContinue

	@(Get-Module -Name PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue |
		Where-Object { $_.Version -eq $targetVersion }).Count -gt 0
}
