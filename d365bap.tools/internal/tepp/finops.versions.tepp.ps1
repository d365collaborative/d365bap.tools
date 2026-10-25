# Tab completion for FinOps versions and builds.
# Reads the cached developer tools catalog, so completing never triggers network calls.

$scbFinOpsAppVersion = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$filterWord = "$wordToComplete" -replace '^[''"]', ''
		$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
		$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

		if (-not (Test-Path -LiteralPath $cachePath)) { return }

		$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

		if ($null -eq $cache.versions) { return }

		$seen = @{}

		foreach ($entry in $cache.versions) {
			$candidates = @(
				@{ Text = "$($entry.appVersion)"; Tip = "Track $($entry.appBuild) - Platform $($entry.platBuild)" }
				@{ Text = "$($entry.appBuild)"; Tip = "Track for $($entry.appVersion) - Platform $($entry.platBuild)" }
			)

			foreach ($candidate in $candidates) {
				if ($seen.ContainsKey($candidate.Text)) { continue }
				$seen[$candidate.Text] = $true

				if ($candidate.Text -like "$filterWord*") {
					New-PSFTeppCompletionResult -CompletionText $candidate.Text -ToolTip $candidate.Tip
				}
			}
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.finops.appversions" -ScriptBlock $scbFinOpsAppVersion -Mode Full

$scbFinOpsAppVersionOnly = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$filterWord = "$wordToComplete" -replace '^[''"]', ''
		$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
		$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

		if (-not (Test-Path -LiteralPath $cachePath)) { return }

		$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

		if ($null -eq $cache.versions) { return }

		$seen = @{}

		foreach ($entry in $cache.versions) {
			$completionText = "$($entry.appVersion)"

			if ($seen.ContainsKey($completionText)) { continue }
			$seen[$completionText] = $true

			if ($completionText -like "$filterWord*") {
				New-PSFTeppCompletionResult -CompletionText $completionText -ToolTip "Track $($entry.appBuild) - Platform $($entry.platBuild)"
			}
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.finops.appversions.only" -ScriptBlock $scbFinOpsAppVersionOnly -Mode Full

$scbFinOpsBuild = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$filterWord = "$wordToComplete" -replace '^[''"]', ''
		$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
		$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

		if (-not (Test-Path -LiteralPath $cachePath)) { return }

		$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

		if ($null -eq $cache.versions) { return }

		$track = $null
		$wanted = "$($fakeBoundParameter['AppVersion'])".Replace('-', '.').Trim()

		if (-not [string]::IsNullOrWhiteSpace($wanted)) {
			$byAppVersion = @($cache.versions | Where-Object { $_.appVersion -eq $wanted } | Select-Object -First 1)

			if ($byAppVersion.Count -gt 0) {
				$track = $byAppVersion[0].appBuild
			}
			else {
				$parts = @($wanted -split '\.')

				if ($parts.Count -eq 4) {
					$wanted = "$($parts[0]).$($parts[1]).$($parts[2])"
				}

				$byBuild = @($cache.versions | Where-Object { $_.appBuild -eq $wanted } | Select-Object -First 1)

				if ($byBuild.Count -gt 0) {
					$track = $byBuild[0].appBuild
				}
			}
		}

		if ([string]::IsNullOrWhiteSpace($track)) {
			$latest = @($cache.versions | Sort-Object -Property { [version]$_.appVersion } | Select-Object -Last 1)

			if ($latest.Count -eq 0) { return }

			$track = $latest[0].appBuild
		}

		$builds = $cache.builds."$track"

		if ($null -eq $builds) { return }

		foreach ($build in $builds) {
			if ("$build" -like "$filterWord*") {
				New-PSFTeppCompletionResult -CompletionText "$build" -ToolTip "Track $track"
			}
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.finops.builds" -ScriptBlock $scbFinOpsBuild -Mode Full

Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsBuild -Parameter AppVersion -Name "d365bap.tools.tepp.finops.appversions"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsPlatform -Parameter Build -Name "d365bap.tools.tepp.finops.builds"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsAsset -Parameter Build -Name "d365bap.tools.tepp.finops.builds"
Register-PSFTeppArgumentCompleter -Command New-UnifiedEnvironmentV2 -Parameter Version -Name "d365bap.tools.tepp.finops.appversions.only"
