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

			It adds a UTF-8 BOM to both files supplied with -Path if they are missing one.

		.EXAMPLE
			PS C:\> Repair-Ps1Utf8Bom -Path .\foo.ps1, .\bar.ps1 | Where-Object Changed

			It repairs the files supplied with -Path and shows only the ones that changed.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $Path
	)

	process {
		foreach ($itemFile in @($Path)) {
			if ([string]::IsNullOrWhiteSpace($itemFile)) {
				continue
			}

			try {
				$bytes = [System.IO.File]::ReadAllBytes($itemFile)
				$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

				if ($hasBom) {
					[PSCustomObject]@{
						PSTypeName = 'Ps1.RepairResult'
						Path       = $itemFile
						Changed    = $false
						Message    = 'Already UTF-8 BOM'
					}
					continue
				}

				$tmpUtf8Bom = New-Object System.Text.UTF8Encoding $true
				$text = [System.IO.File]::ReadAllText($itemFile, [System.Text.UTF8Encoding]::new($false, $false))
				[System.IO.File]::WriteAllText($itemFile, $text, $tmpUtf8Bom)

				[PSCustomObject]@{
					PSTypeName = 'Ps1.RepairResult'
					Path       = $itemFile
					Changed    = $true
					Message    = 'Wrote UTF-8 BOM'
				}
			}
			catch {
				Write-Warning "Failed to repair UTF-8 BOM for '$itemFile': $($_.Exception.Message)"
			}
		}
	}
}
