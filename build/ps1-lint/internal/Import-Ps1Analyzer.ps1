function Get-Ps1PinnedAnalyzerVersion {
	<#
		.SYNOPSIS
			Returns the pinned PSScriptAnalyzer version.

		.DESCRIPTION
			Reads the version pin from the analyzer settings file. The formatter,
			the analyzer, and the setup hook share this pin, so several installed
			versions cannot make formatting and analysis disagree.

		.PARAMETER SettingsPath
			The analyzer settings file that owns the pin.

			Default: Ps1AnalyzerSettings.psd1 in this folder.

		.EXAMPLE
			PS C:\> Get-Ps1PinnedAnalyzerVersion

			It returns the pinned PSScriptAnalyzer version.
			It will read -SettingsPath, which defaults to the settings file.
	#>
	[CmdletBinding()]
	[OutputType([version])]
	param (
		[ValidateNotNullOrEmpty()]
		[string] $SettingsPath = (Join-Path $PSScriptRoot 'Ps1AnalyzerSettings.psd1')
	)

	if (-not (Test-Path -LiteralPath $SettingsPath)) {
		throw "Analyzer settings not found: $SettingsPath"
	}

	$hashSettings = Import-PowerShellDataFile -LiteralPath $SettingsPath
	$strVersion = "$($hashSettings.PSScriptAnalyzerVersion)"

	if ([string]::IsNullOrWhiteSpace($strVersion)) {
		throw "PSScriptAnalyzerVersion is not set in $SettingsPath"
	}

	[version] $strVersion
}

function Import-Ps1Analyzer {
	<#
		.SYNOPSIS
			Imports the pinned PSScriptAnalyzer version.

		.DESCRIPTION
			Removes any other loaded version, imports the pinned version, and
			throws unless it is the only loaded version. Every lint path imports
			through this function, so a newer installed version cannot win.

		.PARAMETER SettingsPath
			The analyzer settings file that owns the pin.

			Default: Ps1AnalyzerSettings.psd1 in this folder.

		.EXAMPLE
			PS C:\> Import-Ps1Analyzer

			It imports the pinned version, or throws when it is missing.
			It will read -SettingsPath, which defaults to the settings file.
	#>
	[CmdletBinding()]
	[OutputType([version])]
	param (
		[ValidateNotNullOrEmpty()]
		[string] $SettingsPath = (Join-Path $PSScriptRoot 'Ps1AnalyzerSettings.psd1')
	)

	$objTarget = Get-Ps1PinnedAnalyzerVersion -SettingsPath $SettingsPath
	$colAvailable = @(Get-Module -Name PSScriptAnalyzer `
			-ListAvailable `
			-ErrorAction SilentlyContinue |
		Where-Object { $_.Version -eq $objTarget })

	if ($colAvailable.Count -eq 0) {
		throw "PSScriptAnalyzer $objTarget is not installed. Run build/ps1-lint/setup/Run.ps1."
	}

	$colLoaded = @(Get-Module -Name PSScriptAnalyzer `
			-ErrorAction SilentlyContinue)

	if ($colLoaded.Count -gt 0) {
		Remove-Module -Name PSScriptAnalyzer `
			-Force `
			-ErrorAction SilentlyContinue
	}

	Import-Module PSScriptAnalyzer `
		-RequiredVersion $objTarget.ToString() `
		-ErrorAction Stop

	$colLoaded = @(Get-Module -Name PSScriptAnalyzer `
			-ErrorAction SilentlyContinue)

	if ($colLoaded.Count -ne 1 -or $colLoaded[0].Version -ne $objTarget) {
		throw "PSScriptAnalyzer $objTarget must be the only loaded version; loaded: $(@($colLoaded | ForEach-Object Version) -join ', ')"
	}

	$objTarget
}
