function Resolve-Ps1Path {
	<#
		.SYNOPSIS
			Finds distinct PowerShell files in paths and directories.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $Path
	)

	$colResolved = [System.Collections.Generic.List[string]]::new()
	$hashSeen = @{}

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
				if (-not $hashSeen.ContainsKey($_.FullName)) {
					$hashSeen[$_.FullName] = $true
					$colResolved.Add($_.FullName) | Out-Null
				}
			}
		}
		elseif ($entry.Extension -eq '.ps1') {
			if (-not $hashSeen.ContainsKey($entry.FullName)) {
				$hashSeen[$entry.FullName] = $true
				$colResolved.Add($entry.FullName) | Out-Null
			}
		}
	}

	@($colResolved)
}
