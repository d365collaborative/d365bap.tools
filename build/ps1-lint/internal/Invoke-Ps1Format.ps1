function Invoke-Ps1Format {
	<#
		.SYNOPSIS
			Formats PowerShell scripts with repository settings.

		.DESCRIPTION
			Uses PSScriptAnalyzer Invoke-Formatter with this repository's
			PowerShell extension settings. Rewrites changed files as UTF-8 with
			a BOM, and adds a missing BOM even when formatting is unchanged.

		.PARAMETER Path
			One or more .ps1 files or directories (directories are scanned recursively).

		.EXAMPLE
			PS C:\> Invoke-Ps1Format -Path .\scripts\foo.ps1

			Formats foo.ps1 using the repo formatter settings.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string[]] $Path,
		[Parameter(Mandatory = $true)]
		[string] $SettingsPath
	)

	begin {
		$allPaths = [System.Collections.Generic.List[string]]::new()

		if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue)) {
			Write-Error 'PSScriptAnalyzer is not installed. Install-Module PSScriptAnalyzer -Scope CurrentUser'
			return
		}

		Import-Module PSScriptAnalyzer -ErrorAction Stop

		if (-not (Test-Path -LiteralPath $SettingsPath)) {
			Write-Error "Formatter settings not found: $SettingsPath"
			return
		}
	}

	process {
		foreach ($item in @($Path)) {
			if (-not [string]::IsNullOrWhiteSpace($item)) {
				$allPaths.Add($item) | Out-Null
			}
		}
	}

	end {
		if ($allPaths.Count -eq 0) {
			return
		}

		$files = @(Resolve-Ps1Path -Path @($allPaths))

		if ($files.Count -eq 0) {
			Write-Warning 'No .ps1 files found for the given Path.'
			return
		}

		$utf8Bom = New-Object System.Text.UTF8Encoding $true

		foreach ($file in $files) {
			try {
				$original = [System.IO.File]::ReadAllText($file, [System.Text.UTF8Encoding]::new($false, $false))
				$formatted = Invoke-Formatter -ScriptDefinition $original -Settings $SettingsPath

				if ($null -eq $formatted) {
					$formatted = $original
				}

				if ($formatted -cne $original) {
					[System.IO.File]::WriteAllText($file, $formatted, $utf8Bom)
				}
				else {
					$bytes = [System.IO.File]::ReadAllBytes($file)
					$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

					if (-not $hasBom) {
						[System.IO.File]::WriteAllText($file, $original, $utf8Bom)
					}
				}
			}
			catch {
				Write-Warning "Failed to format '$file': $($_.Exception.Message)"
			}
		}
	}
}
