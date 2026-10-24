function Repair-Ps1Utf8Bom {
	<#
		.SYNOPSIS
			Ensures .ps1 files are saved as UTF-8 with a BOM.

		.DESCRIPTION
			Accepts full .ps1 paths without resolving them. Preserves files with
			a UTF-8 BOM; rewrites other files with one. Returns an outcome for each file.

		.PARAMETER Path
			One or more full .ps1 file paths.

		.OUTPUTS
			System.Management.Automation.PSCustomObject
			Each object has Path, Changed, and Message properties.

		.EXAMPLE
			PS C:\> Repair-Ps1Utf8Bom -Path C:\scripts\foo.ps1, C:\scripts\bar.ps1

			Adds a UTF-8 BOM to both files if they are missing one.

		.EXAMPLE
			PS C:\> Repair-Ps1Utf8Bom -Path .\foo.ps1, .\bar.ps1 | Where-Object Changed

			Repairs two files and shows only those that were modified.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string[]] $Path
	)

	process {
		foreach ($file in @($Path)) {
			if ([string]::IsNullOrWhiteSpace($file)) {
				continue
			}

			try {
				$bytes = [System.IO.File]::ReadAllBytes($file)
				$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

				if ($hasBom) {
					[PSCustomObject]@{
						PSTypeName = 'Ps1.RepairResult'
						Path       = $file
						Changed    = $false
						Message    = 'Already UTF-8 BOM'
					}
					continue
				}

				$utf8Bom = New-Object System.Text.UTF8Encoding $true
				$text = [System.IO.File]::ReadAllText($file, [System.Text.UTF8Encoding]::new($false, $false))
				[System.IO.File]::WriteAllText($file, $text, $utf8Bom)

				[PSCustomObject]@{
					PSTypeName = 'Ps1.RepairResult'
					Path       = $file
					Changed    = $true
					Message    = 'Wrote UTF-8 BOM'
				}
			}
			catch {
				Write-Warning "Failed to repair UTF-8 BOM for '$file': $($_.Exception.Message)"
			}
		}
	}
}
