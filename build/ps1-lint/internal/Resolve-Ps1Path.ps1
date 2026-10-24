function Resolve-Ps1Path {
	<#
		.SYNOPSIS
			Finds distinct PowerShell files in paths and directories.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string[]] $Path
	)

	$resolved = [System.Collections.Generic.List[string]]::new()
	$seen = @{}

	foreach ($item in @($Path)) {
		if ([string]::IsNullOrWhiteSpace($item)) {
			continue
		}

		if (-not (Test-Path -LiteralPath $item)) {
			continue
		}

		$full = (Resolve-Path -LiteralPath $item).Path
		$entry = Get-Item -LiteralPath $full -Force

		if ($entry.PSIsContainer) {
			Get-ChildItem -LiteralPath $entry.FullName -Filter '*.ps1' -Recurse -File -ErrorAction SilentlyContinue |
			ForEach-Object {
				if (-not $seen.ContainsKey($_.FullName)) {
					$seen[$_.FullName] = $true
					$resolved.Add($_.FullName) | Out-Null
				}
			}
		}
		elseif ($entry.Extension -eq '.ps1') {
			if (-not $seen.ContainsKey($entry.FullName)) {
				$seen[$entry.FullName] = $true
				$resolved.Add($entry.FullName) | Out-Null
			}
		}
	}

	@($resolved)
}
