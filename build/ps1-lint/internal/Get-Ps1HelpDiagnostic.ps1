function Get-Ps1NormalizedHelpText {
	param([string] $Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
	$normalized = $Text.ToLowerInvariant()
	$normalized = [regex]::Replace($normalized, '\s+', ' ')
	$normalized.Trim().TrimEnd('.').Trim()
}

function Get-Ps1ParameterDefaultRecord {
	param($Records, [string] $Argument)
	foreach ($record in @($Records)) {
		if ($null -eq $record) { continue }
		$candidates = @($record.Name) + @($record.Aliases)
		foreach ($candidate in $candidates) {
			if ($null -ne $candidate -and $candidate -ieq $Argument) { return $record }
		}
	}
	$null
}

function Get-Ps1HelpDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$synopsisByGroup = @{}
	foreach ($helpSection in $Analysis.HelpSections) {
		if ($helpSection.Name -ne 'SYNOPSIS') { continue }
		$groupId = $helpSection.GroupId
		if ($null -eq $groupId) { $groupId = 0 }
		if (-not $synopsisByGroup.ContainsKey($groupId)) { $synopsisByGroup[$groupId] = @() }
		$synopsisByGroup[$groupId] += $helpSection.Text
	}

	foreach ($section in $Analysis.HelpSections) {
		$blankLines = @($section.Lines | Where-Object { $_ -eq '' }).Count
		$message = switch ($section.Name) {
			'SYNOPSIS' {
				if ($section.Lines.Count -ne 1 -or $section.Text.Length -ge 60) {
					'SYNOPSIS must be one line and fewer than 60 characters.'
				}
			}
			'DESCRIPTION' {
				if ($section.Text.Length -ge 250 -or $blankLines -gt 2) {
					'DESCRIPTION must be fewer than 250 characters with at most two blank lines in its prose.'
				}
				$parameterReferences = @(
					[regex]::Matches($section.Text, '(?<![\p{L}\p{N}_-])-[\p{L}_][\p{L}\p{N}_-]*') | ForEach-Object Value
					foreach ($name in $section.ParameterNames) {
						$pattern = '(?i)(?<![\p{L}\p{N}_-])' + [regex]::Escape($name) + '(?![\p{L}\p{N}_-])'
						if ($section.Text -match $pattern) { $name }
					}
				)
				if ($parameterReferences.Count -gt 0) {
					'DESCRIPTION must not mention parameters. Move parameter details to PARAMETER sections.'
				}
				$groupId = $section.GroupId
				if ($null -eq $groupId) { $groupId = 0 }
				if ($synopsisByGroup.ContainsKey($groupId)) {
					$descriptionText = Get-Ps1NormalizedHelpText $section.Text
					foreach ($synopsisText in $synopsisByGroup[$groupId]) {
						$synopsisPhrase = Get-Ps1NormalizedHelpText $synopsisText
						if ($synopsisPhrase -ne '' -and $descriptionText.Contains($synopsisPhrase)) {
							'DESCRIPTION must not repeat SYNOPSIS. Add detail beyond the synopsis instead of copying it.'
							break
						}
					}
				}
			}
			'PARAMETER' {
				$defaultRecord = Get-Ps1ParameterDefaultRecord $section.ParameterRecords $section.Argument
				$hasCodeDefault = ($null -ne $defaultRecord -and $defaultRecord.HasDefault)
				$maxBlanks = if ($hasCodeDefault) { 3 } else { 2 }
				$blankWord = if ($hasCodeDefault) { 'three' } else { 'two' }
				if ($section.Text.Length -ge 100 -or $blankLines -gt $maxBlanks) {
					"PARAMETER $($section.Argument) must be fewer than 100 characters with at most $blankWord blank lines in its prose."
				}
				if ($hasCodeDefault) {
					$defaultPattern = '^(?i)default(?:s)?(?:\s+value)?\s*(?::|to\b|is\b)\s*\S'
					$defaultHits = @($section.Lines | Where-Object { $_ -match $defaultPattern })
					if ($defaultHits.Count -eq 0) {
						"PARAMETER $($section.Argument) must document its default value with a trailing Default: ... line."
					}
					else {
						$paragraphs = @()
						$current = @()
						foreach ($helpLine in $section.Lines) {
							if ($helpLine -eq '') {
								if ($current.Count -gt 0) { $paragraphs += , @($current); $current = @() }
							}
							else { $current += $helpLine }
						}
						if ($current.Count -gt 0) { $paragraphs += , @($current) }
						$lastPara = if ($paragraphs.Count -gt 0) { $paragraphs[-1] } else { @() }
						$lastHasDefault = @($lastPara | Where-Object { $_ -match $defaultPattern }).Count -gt 0
						if (-not $lastHasDefault) {
							"Default value explanation must be last in PARAMETER $($section.Argument)."
						}
					}
				}
			}
			'NOTES' {
				$tags = @($section.Lines | Where-Object { $_ -match '^Tags\s*:' })
				$authors = @($section.Lines | Where-Object { $_ -match '^Author\s*:\s*\S' })
				$entries = if ($tags.Count -eq 1) { @(($tags[0] -replace '^Tags\s*:\s*', '') -split ',' | ForEach-Object { $_.Trim() }) } else { @() }
				if ($tags.Count -gt 1 -or
					$tags.Count + $authors.Count -ne $section.Lines.Count -or
					($tags.Count -eq 1 -and ($entries.Count -lt 2 -or $entries -contains ''))) {
					'NOTES allows an optional Tags: line with multiple comma-separated entries and optional nonempty Author: lines. No other content is allowed.'
				}
			}
			'EXAMPLE' {
				if ($blankLines -ne 1) {
					'EXAMPLE must have code, exactly one blank separator, then prose with no blank lines and fewer than 125 characters.'
				}
				else {
					$separator = [Array]::IndexOf($section.Lines, '')
					$prose = $section.Lines[($separator + 1)..($section.Lines.Count - 1)] -join "`n"
					if ($prose.Length -ge 125) { 'EXAMPLE explanation must be fewer than 125 characters; example code is excluded.' }
				}
			}
		}
		if ($message) {
			[pscustomobject]@{
				RuleName   = 'PSHelp' + [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($section.Name.ToLowerInvariant())
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $section.Line
				Column     = $section.Column
				Message    = $message -join ' '
			}
		}
	}

	$helpGroups = @($Analysis.CommentGroups | Where-Object { $_.IsHelp })
	for ($groupIndex = 0; $groupIndex -lt $helpGroups.Count; $groupIndex++) {
		$groupId = $groupIndex + 1
		$group = $helpGroups[$groupIndex]
		$groupParameterSections = @($Analysis.HelpSections | Where-Object { $_.GroupId -eq $groupId -and $_.Name -eq 'PARAMETER' })
		foreach ($record in @($group.ParameterRecords)) {
			if ($null -eq $record -or -not $record.HasDefault) { continue }
			$found = $false
			foreach ($parameterSection in $groupParameterSections) {
				$candidates = @($record.Name) + @($record.Aliases)
				foreach ($candidate in $candidates) {
					if ($null -ne $candidate -and $candidate -ieq $parameterSection.Argument) { $found = $true; break }
				}
				if ($found) { break }
			}
			if ($found) { continue }
			$anchor = @($Analysis.HelpSections | Where-Object { $_.GroupId -eq $groupId }) | Sort-Object Line | Select-Object -First 1
			$anchorLine = if ($null -ne $anchor) { $anchor.Line } else { $group.Line }
			$anchorColumn = if ($null -ne $anchor) { $anchor.Column } else { $group.Column }
			[pscustomobject]@{
				RuleName   = 'PSHelpParameter'
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $anchorLine
				Column     = $anchorColumn
				Message    = "PARAMETER $($record.Name) must document its default value with a trailing Default: ... line."
			}
		}
	}
}
