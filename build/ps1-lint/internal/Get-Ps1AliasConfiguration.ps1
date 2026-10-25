function Get-Ps1AliasConfiguration {
	param([string] $Path, [hashtable] $Cache)

	$rules = @{ AllowedCommandAliases = @(); AllowedParameterAliases = @() }
	$directory = Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent
	$visited = [Collections.Generic.List[string]]::new()
	while ($directory) {
		$visited.Add($directory)
		if ($Cache.ContainsKey($directory)) { $rules = $Cache[$directory]; break }
		$configPath = Join-Path $directory 'ps1-lint.json'
		if (Test-Path -LiteralPath $configPath -PathType Leaf) {
			try {
				$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
				if ($config -isnot [Collections.IDictionary]) { throw 'Expected a JSON object.' }
				if ($config.Contains('rules')) { throw 'The rules object is no longer supported. Use allowedCommandAliases and allowedParameterAliases instead.' }
				foreach ($key in @('allowedCommandAliases', 'allowedParameterAliases')) {
					if (-not $config.Contains($key)) { continue }
					if ($config[$key] -isnot [array]) { throw "$key must be an array of nonempty strings." }
					foreach ($entry in $config[$key]) {
						if ($entry -isnot [string] -or [string]::IsNullOrWhiteSpace($entry)) { throw "$key must be an array of nonempty strings." }
					}
					$rules[$key] = @($config[$key])
				}
			}
			catch { throw "Invalid configuration '$configPath': $($_.Exception.Message)" }
			break
		}
		if (Test-Path -LiteralPath (Join-Path $directory '.git')) { break }
		$parent = Split-Path $directory -Parent
		if ($parent -eq $directory) { break }
		$directory = $parent
	}
	foreach ($item in $visited) { $Cache[$item] = $rules }
	$rules
}
