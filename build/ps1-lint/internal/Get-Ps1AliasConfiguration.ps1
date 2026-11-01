function Get-Ps1AliasConfiguration {
	param([string] $Path, [hashtable] $Cache)

	$hashRules = @{ AllowedCommandAliases = @(); AllowedParameterAliases = @() }
	$directory = Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent
	$colVisited = [Collections.Generic.List[string]]::new()
	while ($directory) {
		$colVisited.Add($directory)
		if ($Cache.ContainsKey($directory)) { $hashRules = $Cache[$directory]; break }
		$configPath = Join-Path $directory 'ps1-lint.json'
		if (Test-Path -LiteralPath $configPath -PathType Leaf) {
			try {
				$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
				if ($config -isnot [Collections.IDictionary]) { throw 'Expected a JSON object.' }
				if ($config.Contains('rules')) { throw 'The rules object is no longer supported. Use allowedCommandAliases and allowedParameterAliases instead.' }
				foreach ($itemKey in @('allowedCommandAliases', 'allowedParameterAliases')) {
					if (-not $config.Contains($itemKey)) { continue }
					if ($config[$itemKey] -isnot [array]) { throw "$itemKey must be an array of nonempty strings." }
					foreach ($itemEntry in $config[$itemKey]) {
						if ($itemEntry -isnot [string] -or [string]::IsNullOrWhiteSpace($itemEntry)) { throw "$itemKey must be an array of nonempty strings." }
					}
					$hashRules[$itemKey] = @($config[$itemKey])
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
	foreach ($item in $colVisited) { $Cache[$item] = $hashRules }
	$hashRules
}
