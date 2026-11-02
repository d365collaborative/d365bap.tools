<#
	.SYNOPSIS
		Calculates the formatted text of one script.

	.DESCRIPTION
		Reads the file once and runs Invoke-Formatter with the repository
		settings. It reports the text and whether a write is needed without
		writing it, so check-only analysis can use the formatted text.

	.PARAMETER Path
		The .ps1 file to format.

	.PARAMETER SettingsPath
		The formatter settings file.

	.EXAMPLE
		PS C:\> Get-Ps1FormattedContent -Path .\script.ps1 -SettingsPath .\Ps1FormatSettings.psd1

		It returns the formatted text.
		It will use -Path .\script.ps1.
		It will use -SettingsPath .\Ps1FormatSettings.psd1.

	.OUTPUTS
		PSCustomObject with Path, Content, HasBom, and Changed.
#>
function Get-Ps1FormattedContent {
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string] $Path,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $SettingsPath
	)

	if (-not (Test-Path -LiteralPath $SettingsPath)) {
		throw "Formatter settings not found: $SettingsPath"
	}

	$original = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $false))
	$formatted = Invoke-Formatter `
		-ScriptDefinition $original `
		-Settings $SettingsPath

	if ($null -eq $formatted) {
		$formatted = $original
	}

	$bytes = [System.IO.File]::ReadAllBytes($Path)
	$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

	[pscustomobject]@{
		Path    = $Path
		Content = $formatted
		HasBom  = $hasBom
		Changed = ($formatted -cne $original) -or (-not $hasBom)
	}
}
