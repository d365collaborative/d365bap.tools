<#
	Intelligent UDE PackagesLocalDirectory version completion.

	Registered as native argument completers (rather than through the
	PSFramework TEPP host) so completion keeps working independent of the
	TEPP TabExpansion2 hook state in the host session.

	Offers installed versions under %LOCALAPPDATA%\Microsoft\Dynamics365
	where PackagesLocalDirectory exists. Displayed as
	"AppVersion (PackagesVersion)", sorted by AppVersion ascending.
	Versions without a catalog entry show the plain PackagesVersion.
	The Version parameter inserts the displayed label, quoted when needed.
	Set-UdeConfig keeps the plain PackagesVersion for its path lookup.
	Quoting mirrors the word being completed.
#>

$udePackageLocalDirectoryCompleter = {
	param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

	# The native completer contract supplies these parameters even when this
	# completer only needs the word being completed.
	$null = $commandName, $commandAst, $fakeBoundParameters

	try {
		$rawWord = "$wordToComplete"
		$filterWord = $rawWord.Trim("'", '"')

		$quoteChar = ''
		if ($rawWord.StartsWith("'")) { $quoteChar = "'" }
		elseif ($rawWord.StartsWith('"')) { $quoteChar = '"' }

		if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { return }

		$packagesRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Dynamics365'

		if (-not (Test-Path -LiteralPath $packagesRoot)) { return }

		$mapAppVersion = @{}

		try {
			$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
			$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

			if (Test-Path -LiteralPath $cachePath) {
				$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

				foreach ($entry in @($cache.versions)) {
					$track = if ($null -ne $entry.appBuild) { "$($entry.appBuild)" } else { "$($entry.AppBuild)" }
					$app = if ($null -ne $entry.appVersion) { "$($entry.appVersion)" } else { "$($entry.AppVersion)" }

					if ([string]::IsNullOrWhiteSpace($track) -or [string]::IsNullOrWhiteSpace($app)) { continue }
					if (-not $mapAppVersion.ContainsKey($track)) { $mapAppVersion[$track] = $app }
				}
			}
		}
		catch { $null = $_.Exception.Message }

		$found = @(
			Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
			Where-Object { Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory') } |
			ForEach-Object {
				$packagesVersion = $_.Name
				$parts = @($packagesVersion -split '\.')
				$track = if ($parts.Count -ge 3) { "$($parts[0]).$($parts[1]).$($parts[2])" } else { $packagesVersion }
				$appVersion = if ($mapAppVersion.ContainsKey($track)) { $mapAppVersion[$track] } else { '' }

				$display = if (-not [string]::IsNullOrWhiteSpace($appVersion)) { "$appVersion ($packagesVersion)" } else { $packagesVersion }
				$sortVersion = if (-not [string]::IsNullOrWhiteSpace($appVersion)) { $appVersion } else { $packagesVersion }

				[PSCustomObject]@{
					PackagesVersion = $packagesVersion
					Display         = $display
					SortVersion     = $sortVersion
					Path            = (Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory')
				}
			} |
			Where-Object { $_.PackagesVersion -like "$filterWord*" -or $_.Display -like "$filterWord*" } |
			Sort-Object { [version]$_.SortVersion }, { [version]$_.PackagesVersion }
		)

		foreach ($item in $found) {
			$completionText = $item.PackagesVersion

			if ($parameterName -eq 'Version') {
				$completionText = $item.Display
			}

			if ($quoteChar -ne '') {
				$completionText = "$quoteChar$completionText$quoteChar"
			}
			elseif ($completionText -match '\s') {
				$completionText = "'$completionText'"
			}

			[System.Management.Automation.CompletionResult]::new($completionText, $item.Display, 'ParameterValue', $item.Path)
		}
	}
	catch { $null = $_.Exception.Message }
}

Register-ArgumentCompleter -CommandName Get-UdePackageLocalDirectory -ParameterName Version -ScriptBlock $udePackageLocalDirectoryCompleter
Register-ArgumentCompleter -CommandName Set-UdeConfig -ParameterName PackagesVersion -ScriptBlock $udePackageLocalDirectoryCompleter
