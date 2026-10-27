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
		$filterWord = "$wordToComplete".Trim("'", '"')
		$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
		$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

		if (-not (Test-Path -LiteralPath $cachePath)) { return }

		$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

		if ($null -eq $cache.versions) { return }

		$seen = @{}
		$foundVersions = @()

		foreach ($entry in $cache.versions) {
			$candidates = @(
				@{ Text = "$($entry.appVersion)"; Tip = "Track $($entry.appBuild) - Platform $($entry.platBuild)" }
				@{ Text = "$($entry.appBuild)"; Tip = "Track for $($entry.appVersion) - Platform $($entry.platBuild)" }
			)

			foreach ($candidate in $candidates) {
				if ($seen.ContainsKey($candidate.Text)) { continue }
				$seen[$candidate.Text] = $true

				if ($candidate.Text -like "$filterWord*") {
					$foundVersions += [PsCustomObject]@{ Text = $candidate.Text; Tip = $candidate.Tip }
				}
			}
		}

		foreach ($found in @($foundVersions | Sort-Object -Property { [version]$_.Text })) {
			New-PSFTeppCompletionResult -CompletionText $found.Text -ToolTip $found.Tip
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
		$filterWord = "$wordToComplete".Trim("'", '"')
		$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
		$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

		if (-not (Test-Path -LiteralPath $cachePath)) { return }

		$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

		if ($null -eq $cache.versions) { return }

		$seen = @{}
		$foundVersions = @()

		foreach ($entry in $cache.versions) {
			$completionText = "$($entry.appVersion)"

			if ($seen.ContainsKey($completionText)) { continue }
			$seen[$completionText] = $true

			if ($completionText -like "$filterWord*") {
				$foundVersions += [PsCustomObject]@{ Text = $completionText; Tip = "Track $($entry.appBuild) - Platform $($entry.platBuild)" }
			}
		}

		foreach ($found in @($foundVersions | Sort-Object -Property { [version]$_.Text })) {
			New-PSFTeppCompletionResult -CompletionText $found.Text -ToolTip $found.Tip
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
		$filterWord = "$wordToComplete".Trim("'", '"')
		$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
		$cachePath = Join-Path (Join-Path $base 'd365bap.tools') 'finopsversions.json'

		if (-not (Test-Path -LiteralPath $cachePath)) { return }

		$cache = Get-Content -LiteralPath $cachePath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

		if ($null -eq $cache.versions) { return }

		$typed = "$filterWord".Replace('-', '.').Trim()
		$track = $null

		if (-not [string]::IsNullOrWhiteSpace($typed)) {
			$byAppVersion = @($cache.versions | Where-Object { $_.appVersion -eq $typed } | Select-Object -First 1)

			if ($byAppVersion.Count -gt 0) {
				$track = "$($byAppVersion[0].appBuild)"
			}
			else {
				$parts = @($typed -split '\.')
				$candidate = if ($parts.Count -ge 3) { "$($parts[0]).$($parts[1]).$($parts[2])" } else { $typed }

				$byBuild = @($cache.versions | Where-Object { $_.appBuild -eq $candidate } | Select-Object -First 1)

				if ($byBuild.Count -gt 0) {
					$track = "$($byBuild[0].appBuild)"
				}
			}
		}

		if ([string]::IsNullOrWhiteSpace($track)) {
			$boundApp = "$($fakeBoundParameter['AppVersion'])".Replace('-', '.').Trim()

			if (-not [string]::IsNullOrWhiteSpace($boundApp)) {
				$byBoundVer = @($cache.versions | Where-Object { $_.appVersion -eq $boundApp } | Select-Object -First 1)

				if ($byBoundVer.Count -gt 0) {
					$track = "$($byBoundVer[0].appBuild)"
				}
				else {
					$boundParts = @($boundApp -split '\.')
					$boundCandidate = if ($boundParts.Count -ge 3) { "$($boundParts[0]).$($boundParts[1]).$($boundParts[2])" } else { $boundApp }

					$byBoundBuild = @($cache.versions | Where-Object { $_.appBuild -eq $boundCandidate } | Select-Object -First 1)

					if ($byBoundBuild.Count -gt 0) {
						$track = "$($byBoundBuild[0].appBuild)"
					}
				}
			}
		}

		$targetBuilds = @()

		if (-not [string]::IsNullOrWhiteSpace($track) -and $null -ne $cache.builds) {
			$targetBuilds = @($cache.builds."$track" | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") })
		}

		if ($targetBuilds.Count -gt 0) {
			$seen = @{}
			$foundBuilds = @()

			foreach ($build in $targetBuilds) {
				if ("$build" -notlike "$filterWord*") { continue }
				if ($seen.ContainsKey("$build")) { continue }
				$seen["$build"] = $true
				$foundBuilds += [PsCustomObject]@{ Build = "$build"; Track = "$track" }
			}

			foreach ($match in @($foundBuilds | Sort-Object -Property { [version]$_.Build } -Descending)) {
				New-PSFTeppCompletionResult -CompletionText $match.Build -ToolTip "Track $($match.Track)"
			}

			return
		}

		if (-not [string]::IsNullOrWhiteSpace($track)) {
			New-PSFTeppCompletionResult -CompletionText $track -ToolTip "Track $track - latest build resolves live"
			return
		}

		$seen = @{}
		$foundBuilds = @()

		foreach ($versionEntry in @($cache.versions)) {
			$offerTrack = "$($versionEntry.appBuild)"

			foreach ($build in @($cache.builds."$offerTrack" | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") })) {
				if ("$build" -notlike "$filterWord*") { continue }
				if ($seen.ContainsKey("$build")) { continue }
				$seen["$build"] = $true
				$foundBuilds += [PsCustomObject]@{ Build = "$build"; Track = "$offerTrack" }
			}
		}

		foreach ($match in @($foundBuilds | Sort-Object -Property { [version]$_.Build } -Descending)) {
			New-PSFTeppCompletionResult -CompletionText $match.Build -ToolTip "Track $($match.Track)"
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.finops.builds" -ScriptBlock $scbFinOpsBuild -Mode Full

Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsBuild -Parameter AppVersion -Name "d365bap.tools.tepp.finops.appversions.only"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsVersion -Parameter AppVersion -Name "d365bap.tools.tepp.finops.appversions.only"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsPlatform -Parameter AppVersion -Name "d365bap.tools.tepp.finops.appversions.only"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsPlatform -Parameter Build -Name "d365bap.tools.tepp.finops.builds"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsAsset -Parameter AppVersion -Name "d365bap.tools.tepp.finops.appversions.only"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsAsset -Parameter Build -Name "d365bap.tools.tepp.finops.builds"
Register-PSFTeppArgumentCompleter -Command New-UnifiedEnvironmentV2 -Parameter Version -Name "d365bap.tools.tepp.finops.appversions.only"
