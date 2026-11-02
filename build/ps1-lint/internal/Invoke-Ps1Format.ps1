. "$PSScriptRoot/Import-Ps1Analyzer.ps1"
. "$PSScriptRoot/Get-Ps1FormattedContent.ps1"

function Invoke-Ps1Format {
	<#
		.SYNOPSIS
			Formats PowerShell scripts with repository settings.

		.DESCRIPTION
			Runs Invoke-Formatter with the repository settings and enforces a
			UTF-8 BOM. Imports exactly the pinned analyzer version, so another
			installed version cannot change the result.

		.PARAMETER Path
			One or more .ps1 files or directories (directories are scanned recursively).

		.EXAMPLE
			PS C:\> Invoke-Ps1Format -Path .\scripts\foo.ps1

			It formats foo.ps1 using -Path and the repo formatter settings.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $Path,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $SettingsPath
	)

	begin {
		$colAllPaths = [System.Collections.Generic.List[string]]::new()
		$colFailures = [System.Collections.Generic.List[string]]::new()

		Import-Ps1Analyzer > $null

		if (-not (Test-Path -LiteralPath $SettingsPath)) {
			throw "Formatter settings not found: $SettingsPath"
		}
	}

	process {
		foreach ($item in @($Path)) {
			if (-not [string]::IsNullOrWhiteSpace($item)) {
				$colAllPaths.Add($item) > $null
			}
		}
	}

	end {
		if ($colAllPaths.Count -eq 0) {
			return
		}

		$colFiles = @(Resolve-Ps1Path -Path @($colAllPaths))

		if ($colFiles.Count -eq 0) {
			Write-Warning 'No .ps1 files found for the given Path.'
			return
		}

		$objUtf8Bom = New-Object System.Text.UTF8Encoding $true

		foreach ($itemFile in $colFiles) {
			try {
				$objContent = Get-Ps1FormattedContent -Path $itemFile `
					-SettingsPath $SettingsPath

				if ($objContent.Changed) {
					[System.IO.File]::WriteAllText($itemFile, $objContent.Content, $objUtf8Bom)
				}
			}
			catch {
				$colFailures.Add("Failed to format '$itemFile': $($_.Exception.Message)") > $null
			}
		}

		if ($colFailures.Count -gt 0) {
			throw ($colFailures -join [Environment]::NewLine)
		}
	}
}
