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

function Get-Ps1ExampleMessage {
	param($Section, $Sections)

	if (@($Section.Lines | Where-Object { $_ -eq '' }).Count -ne 1) {
		'EXAMPLE must have code, exactly one blank separator, then prose with no blank lines.'
		return
	}
	$separator = [Array]::IndexOf($Section.Lines, '')
	$prose = @($Section.Lines[($separator + 1)..($Section.Lines.Count - 1)])
	$dependentPattern = '(?i)' + (@(
			'\b(?:same as|as (?:shown|described|explained|demonstrated|in|with)|see|refer to|like|unlike|similar to)\s+(?:(?:the|an?)\s+)?(?:above|below|previous|preceding|earlier|next|first|last|other|example\s*\d)'
			'\b(?:above|below|previous|preceding|earlier|following)\s+example\b'
			'\bexample\s+(?:above|below|#?\d+)\b'
			'\b(?:same|similar|as)\s+(?:as\s+)?(?:before|above|below)\b'
			'\b(?:same|identical)\s+(?:command|operation|result|behavior)\b'
		) -join '|')
	if (($prose -join ' ') -match $dependentPattern) {
		'EXAMPLE prose must stand alone. Do not refer to another example or say "Same as above".'
	}
	if ($prose[0] -notmatch '^(?i)It\s+' -and $prose[0].Length -ge 125) {
		'EXAMPLE summary must be fewer than 125 characters.'
	}
	$itLines = @($prose | Where-Object { $_ -match '^(?i)It\s+\S' })
	foreach ($line in $itLines) {
		if ($line.Length -gt 80) { 'EXAMPLE It lines must be 80 characters or fewer.'; break }
	}
	$details = if ($prose[0] -match '^(?i)It\s+') { $prose } else { @($prose | Select-Object -Skip 1) }
	if (@($details | Where-Object { $_ -notmatch '^(?i)It\s+\S' }).Count -gt 0) {
		'EXAMPLE detail lines must each start with "It " or "It will ".'
	}

	$code = ($Section.Lines[0..($separator - 1)] -join "`n") -replace '(?m)^\s*(?:PS [^>\r\n]*>|>>)\s?', ''
	$parseErrors = $null
	$ast = [Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$parseErrors)
	if ($parseErrors.Count -gt 0) {
		'EXAMPLE code must be valid PowerShell so parameter coverage can be checked.'
		return
	}
	$required = @{}
	$parameterSections = @($Sections | Where-Object { $_.GroupId -eq $Section.GroupId -and $_.Name -eq 'PARAMETER' })
	$defaultPattern = '(?i)\bdefaults?\b|\b(?:when|if)\s+(?:omitted|not\s+(?:specified|provided|supplied|set))\b'
	foreach ($command in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $command.GetCommandName()
		$isOwner = $null -ne $commandName -and [IO.Path]::GetFileNameWithoutExtension(($commandName -split '\\')[-1]) -ieq $Section.CommandName
		$specified = @{}
		$elements = @($command.CommandElements | Select-Object -Skip 1)
		for ($index = 0; $index -lt $elements.Count; $index++) {
			$element = $elements[$index]
			if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			$name = $element.ParameterName
			$record = if ($isOwner) { Get-Ps1ParameterDefaultRecord $Section.ParameterRecords $name }
			if ($null -ne $record) { $name = $record.Name }
			$specified[$name] = $true
			$required[$name] = if ($null -ne $record) { @($record.Name) + @($record.Aliases) } else { @($name) }
		}
		if (-not $isOwner) { continue }
		$positionals = @()
		for ($index = 0; $index -lt $elements.Count; $index++) {
			$element = $elements[$index]
			if ($element -is [Management.Automation.Language.CommandParameterAst]) {
				$record = Get-Ps1ParameterDefaultRecord $Section.ParameterRecords $element.ParameterName
				$isSwitch = ($null -ne $record -and $record.IsSwitch) -or $element.ParameterName -in @('WhatIf', 'Confirm', 'Verbose', 'Debug')
				if ($null -eq $element.Argument -and -not $isSwitch) { $index++ }
				continue
			}
			if ($element -is [Management.Automation.Language.VariableExpressionAst] -and $element.Splatted) {
				'EXAMPLE must spell out splatted parameters so each can be explained on its own It line.'
				continue
			}
			$positionals += $element
		}
		$unbound = @($Section.ParameterRecords | Where-Object { -not $specified.ContainsKey($_.Name) -and -not $_.IsSwitch -and $_.Position -ge 0 } | Sort-Object Position)
		if ($positionals.Count -gt $unbound.Count) {
			'EXAMPLE positional arguments could not be matched to declared parameters. Use explicit parameter names.'
		}
		for ($index = 0; $index -lt [Math]::Min($positionals.Count, $unbound.Count); $index++) {
			$record = $unbound[$index]
			$specified[$record.Name] = $true
			$required[$record.Name] = @($record.Name) + @($record.Aliases)
		}
		foreach ($record in $Section.ParameterRecords) {
			if ($specified.ContainsKey($record.Name)) { continue }
			$documented = @($parameterSections | Where-Object { $_.Argument -in (@($record.Name) + @($record.Aliases)) })
			$defaultLines = @($documented.Lines | Where-Object { $_ -match $defaultPattern })
			if (-not $record.HasDefault -and $defaultLines.Count -eq 0) { continue }
			if ($record.IsSearchDefault -or (-not $record.HasDefault -and ($defaultLines -join ' ') -match '[*?\[]|(?i)\b(?:wildcards?|like (?:search|match|pattern))\b|-like\b')) { continue }
			$required[$record.Name] = @($record.Name) + @($record.Aliases)
		}
	}

	$covered = @{}
	foreach ($line in $itLines) {
		$names = @(foreach ($name in $required.Keys) {
				foreach ($candidate in $required[$name]) {
					if ($line -match ('(?i)(?<![\p{L}\p{N}_-])-' + [regex]::Escape($candidate) + '(?![\p{L}\p{N}_-])')) { $name; break }
				}
			})
		if ($names.Count -gt 1) {
			"EXAMPLE must explain each parameter on a separate It line: $($names -join ', ')."
		}
		elseif ($names.Count -eq 1) { $covered[$names[0]] = $true }
	}
	foreach ($name in @($required.Keys | Sort-Object)) {
		if (-not $covered.ContainsKey($name)) {
			"EXAMPLE must explain -$name on its own line starting with 'It ' or 'It will ', including its applicable default when omitted."
		}
	}
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
				Get-Ps1ExampleMessage -Section $section -Sections $Analysis.HelpSections
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
