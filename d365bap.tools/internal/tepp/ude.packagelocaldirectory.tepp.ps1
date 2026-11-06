<#
	Intelligent UDE PackagesLocalDirectory version completion.

	Registered as native argument completers (rather than through the
	PSFramework TEPP host) so completion keeps working independent of the
	TEPP TabExpansion2 hook state in the host session.

	Offers installed versions under %LOCALAPPDATA%\Microsoft\Dynamics365
	where PackagesLocalDirectory exists. Displayed as
	"AppVersion (PackagesVersion)", sorted by AppVersion ascending.
	Builds newer than every known catalog track show as
	"Prerelease (PackagesVersion)" and sort last.
	The inserted value stays the plain PackagesVersion so -Version filtering
	keeps working. Quoting mirrors the word being completed.
#>

$udePackageLocalDirectoryCompleter = {
	param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

	# The native completer contract supplies these parameters even when this
	# completer only needs the word being completed.
	$null = $commandName, $parameterName, $commandAst, $fakeBoundParameters

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

		$maxTrack = $null

		if ($mapAppVersion.Count -gt 0) {
			$maxTrack = ($mapAppVersion.Keys | ForEach-Object { try { [version]$_ } catch { $null } } | Where-Object { $_ } | Sort-Object | Select-Object -Last 1)
		}

		$found = @(
			Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
			Where-Object { Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory') } |
			ForEach-Object {
				$packagesVersion = $_.Name
				$parts = @($packagesVersion -split '\.')
				$track = if ($parts.Count -ge 3) { "$($parts[0]).$($parts[1]).$($parts[2])" } else { $packagesVersion }
				$appVersion = if ($mapAppVersion.ContainsKey($track)) { $mapAppVersion[$track] } else { '' }

				$trackVersion = $null
				try { $trackVersion = [version]$track } catch { $trackVersion = $null }

				$isPrerelease = $false
				if ([string]::IsNullOrWhiteSpace($appVersion) -and $null -ne $trackVersion -and $null -ne $maxTrack -and $trackVersion -gt $maxTrack) {
					$isPrerelease = $true
				}

				$display = if (-not [string]::IsNullOrWhiteSpace($appVersion)) { "$appVersion ($packagesVersion)" } elseif ($isPrerelease) { "Prerelease ($packagesVersion)" } else { $packagesVersion }
				$sortVersion = if (-not [string]::IsNullOrWhiteSpace($appVersion)) { $appVersion } elseif ($isPrerelease -and $null -ne $trackVersion) { "$trackVersion" } else { '0.0.0.0' }

				[PSCustomObject]@{
					PackagesVersion = $packagesVersion
					AppVersion      = $appVersion
					IsPrerelease    = $isPrerelease
					Display         = $display
					SortVersion     = $sortVersion
					Path            = (Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory')
				}
			} |
			Where-Object { $_.PackagesVersion -like "$filterWord*" -or $_.AppVersion -like "$filterWord*" -or $_.Display -like "$filterWord*" } |
			Sort-Object { [version]$_.SortVersion }, { [version]$_.PackagesVersion }
		)

		foreach ($item in $found) {
			$completionText = $item.PackagesVersion

			if ($quoteChar -ne '') {
				$completionText = "$quoteChar$($item.PackagesVersion)$quoteChar"
			}

			[System.Management.Automation.CompletionResult]::new($completionText, $item.Display, 'ParameterValue', $item.Path)
		}
	}
	catch { $null = $_.Exception.Message }
}

Register-ArgumentCompleter -CommandName Get-UdePackageLocalDirectory -ParameterName Version -ScriptBlock $udePackageLocalDirectoryCompleter
Register-ArgumentCompleter -CommandName Set-UdeConfig -ParameterName PackagesVersion -ScriptBlock $udePackageLocalDirectoryCompleter
