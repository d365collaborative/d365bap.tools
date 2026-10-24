function Get-Ps1AliasConfiguration {
	param([string] $Path, [hashtable] $Cache)

	$rules = @{ PSAvoidCommandAliases = $true; PSAvoidParameterAliases = $true }
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
				if ($config.Contains('rules')) {
					if ($config.rules -isnot [Collections.IDictionary]) { throw 'rules must be an object.' }
					foreach ($name in $config.rules.Keys) {
						if (-not $rules.ContainsKey($name)) { throw "Unknown alias rule '$name'." }
						if ($config.rules[$name] -isnot [bool]) { throw "Rule '$name' must be true or false." }
						$rules[$name] = $config.rules[$name]
					}
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
