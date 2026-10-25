function Ensure-PsScriptAnalyzer {
	<#
		.SYNOPSIS
			Ensures PSScriptAnalyzer is available.

		.DESCRIPTION
			Returns true when PSScriptAnalyzer is available. Otherwise installs it
			silently for CurrentUser. Returns false when installation fails or the
			module is still unavailable.

		.EXAMPLE
			PS C:\> Ensure-PsScriptAnalyzer

			Returns $true once PSScriptAnalyzer is importable.
	#>
	[CmdletBinding()]
	param()

	if (Get-Module -Name PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue) {
		return $true
	}

	try {
		$repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
		if ($repo.InstallationPolicy -ne 'Trusted') {
			Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop | Out-Null
		}
	}
	catch {
		return $false
	}

	if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
		$null = Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue
	}

	$ProgressPreference = 'SilentlyContinue'

	$null = Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -ErrorAction SilentlyContinue

	return (Get-Module -Name PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue) -ne $null
}
