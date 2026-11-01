function Get-Ps1NormalizedHelpText {
	param([string] $Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
	$normalized = $Text.ToLowerInvariant()
	$normalized = [regex]::Replace($normalized, '\s+', ' ')
	$normalized.Trim().TrimEnd('.').Trim()
}

function Get-Ps1ParameterDefaultRecord {
	param($Records, [string] $Argument)
	foreach ($itemRecord in @($Records)) {
		if ($null -eq $itemRecord) { continue }
		$tmpCandidates = @($itemRecord.Name) + @($itemRecord.Aliases)
		foreach ($itemCandidate in $tmpCandidates) {
			if ($null -ne $itemCandidate -and $itemCandidate -ieq $Argument) { return $itemRecord }
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
	$colProse = @($Section.Lines[($separator + 1)..($Section.Lines.Count - 1)])
	$dependentPattern = '(?i)' + (@(
			'\b(?:same as|as (?:shown|described|explained|demonstrated|in|with)|see|refer to|like|unlike|similar to)\s+(?:(?:the|an?)\s+)?(?:above|below|previous|preceding|earlier|next|first|last|other|example\s*\d)'
			'\b(?:above|below|previous|preceding|earlier|following)\s+example\b'
			'\bexample\s+(?:above|below|#?\d+)\b'
			'\b(?:same|similar|as)\s+(?:as\s+)?(?:before|above|below)\b'
			'\b(?:same|identical)\s+(?:command|operation|result|behavior)\b'
		) -join '|')
	if (($colProse -join ' ') -match $dependentPattern) {
		'EXAMPLE prose must stand alone. Do not refer to another example or say "Same as above".'
	}
	if ($colProse[0] -notmatch '^(?i)It\s+' -and $colProse[0].Length -ge 125) {
		'EXAMPLE summary must be fewer than 125 characters.'
	}
	$colItLines = @($colProse | Where-Object { $_ -match '^(?i)It\s+\S' })
	foreach ($itemLine in $colItLines) {
		if ($itemLine.Length -gt 80) { 'EXAMPLE It lines must be 80 characters or fewer.'; break }
	}
	$details = if ($colProse[0] -match '^(?i)It\s+') { $colProse } else { @($colProse | Select-Object -Skip 1) }
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
	$hashRequired = @{}
	$colParameterSections = @($Sections | Where-Object { $_.GroupId -eq $Section.GroupId -and $_.Name -eq 'PARAMETER' })
	$defaultPattern = '(?i)\bdefaults?\b|\b(?:when|if)\s+(?:omitted|not\s+(?:specified|provided|supplied|set))\b'
	foreach ($itemCommand in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		$isOwner = $null -ne $commandName -and [IO.Path]::GetFileNameWithoutExtension(($commandName -split '\\')[-1]) -ieq $Section.CommandName
		$tmpSpecified = @{}
		$tmpElements = @($itemCommand.CommandElements | Select-Object -Skip 1)
		for ($index = 0; $index -lt $tmpElements.Count; $index++) {
			$element = $tmpElements[$index]
			if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			$itemName = $element.ParameterName
			$itemRecord = if ($isOwner) { Get-Ps1ParameterDefaultRecord $Section.ParameterRecords $itemName }
			if ($null -ne $itemRecord) { $itemName = $itemRecord.Name }
			$tmpSpecified[$itemName] = $true
			$hashRequired[$itemName] = if ($null -ne $itemRecord) { @($itemRecord.Name) + @($itemRecord.Aliases) } else { @($itemName) }
		}
		if (-not $isOwner) { continue }
		$tmpPositionals = @()
		for ($index = 0; $index -lt $tmpElements.Count; $index++) {
			$element = $tmpElements[$index]
			if ($element -is [Management.Automation.Language.CommandParameterAst]) {
				$itemRecord = Get-Ps1ParameterDefaultRecord $Section.ParameterRecords $element.ParameterName
				$isSwitch = ($null -ne $itemRecord -and $itemRecord.IsSwitch) -or $element.ParameterName -in @('WhatIf', 'Confirm', 'Verbose', 'Debug')
				if ($null -eq $element.Argument -and -not $isSwitch) { $index++ }
				continue
			}
			if ($element -is [Management.Automation.Language.VariableExpressionAst] -and $element.Splatted) {
				'EXAMPLE must spell out splatted parameters so each can be explained on its own It line.'
				continue
			}
			$tmpPositionals += $element
		}
		$tmpUnbound = @($Section.ParameterRecords | Where-Object { -not $tmpSpecified.ContainsKey($_.Name) -and -not $_.IsSwitch -and $_.Position -ge 0 } | Sort-Object Position)
		if ($tmpPositionals.Count -gt $tmpUnbound.Count) {
			'EXAMPLE positional arguments could not be matched to declared parameters. Use explicit parameter names.'
		}
		for ($index = 0; $index -lt [Math]::Min($tmpPositionals.Count, $tmpUnbound.Count); $index++) {
			$itemRecord = $tmpUnbound[$index]
			$tmpSpecified[$itemRecord.Name] = $true
			$hashRequired[$itemRecord.Name] = @($itemRecord.Name) + @($itemRecord.Aliases)
		}
		foreach ($itemRecord in $Section.ParameterRecords) {
			if ($tmpSpecified.ContainsKey($itemRecord.Name)) { continue }
			$tmpDocumented = @($colParameterSections | Where-Object { $_.Argument -in (@($itemRecord.Name) + @($itemRecord.Aliases)) })
			$tmpDefaultLines = @($tmpDocumented.Lines | Where-Object { $_ -match $defaultPattern })
			if (-not $itemRecord.HasDefault -and $tmpDefaultLines.Count -eq 0) { continue }
			if ($itemRecord.IsSearchDefault -or (-not $itemRecord.HasDefault -and ($tmpDefaultLines -join ' ') -match '[*?\[]|(?i)\b(?:wildcards?|like (?:search|match|pattern))\b|-like\b')) { continue }
			$hashRequired[$itemRecord.Name] = @($itemRecord.Name) + @($itemRecord.Aliases)
		}
	}

	$hashCovered = @{}
	foreach ($itemLine in $colItLines) {
		$tmpNames = @(foreach ($itemName in $hashRequired.Keys) {
				foreach ($itemCandidate in $hashRequired[$itemName]) {
					if ($itemLine -match ('(?i)(?<![\p{L}\p{N}_-])-' + [regex]::Escape($itemCandidate) + '(?![\p{L}\p{N}_-])')) { $itemName; break }
				}
			})
		if ($tmpNames.Count -gt 1) {
			"EXAMPLE must explain each parameter on a separate It line: $($tmpNames -join ', ')."
		}
		elseif ($tmpNames.Count -eq 1) { $hashCovered[$tmpNames[0]] = $true }
	}
	foreach ($itemName in @($hashRequired.Keys | Sort-Object)) {
		if (-not $hashCovered.ContainsKey($itemName)) {
			"EXAMPLE must explain -$itemName on its own line starting with 'It ' or 'It will ', including its applicable default when omitted."
		}
	}
}

function Get-Ps1HelpDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$hashSynopsisByGroup = @{}
	foreach ($itemHelpSection in $Analysis.HelpSections) {
		if ($itemHelpSection.Name -ne 'SYNOPSIS') { continue }
		$groupId = $itemHelpSection.GroupId
		if ($null -eq $groupId) { $groupId = 0 }
		if (-not $hashSynopsisByGroup.ContainsKey($groupId)) { $hashSynopsisByGroup[$groupId] = @() }
		$hashSynopsisByGroup[$groupId] += $itemHelpSection.Text
	}

	foreach ($itemSection in $Analysis.HelpSections) {
		$blankLines = @($itemSection.Lines | Where-Object { $_ -eq '' }).Count
		$message = switch ($itemSection.Name) {
			'SYNOPSIS' {
				if ($itemSection.Lines.Count -ne 1 -or $itemSection.Text.Length -ge 60) {
					'SYNOPSIS must be one line and fewer than 60 characters.'
				}
			}
			'DESCRIPTION' {
				if ($itemSection.Text.Length -ge 250 -or $blankLines -gt 2) {
					'DESCRIPTION must be fewer than 250 characters with at most two blank lines in its prose.'
				}
				$tmpParameterReferences = @(
					[regex]::Matches($itemSection.Text, '(?<![\p{L}\p{N}_-])-[\p{L}_][\p{L}\p{N}_-]*') | ForEach-Object Value
					foreach ($itemName in $itemSection.ParameterNames) {
						$pattern = '(?i)(?<![\p{L}\p{N}_-])' + [regex]::Escape($itemName) + '(?![\p{L}\p{N}_-])'
						if ($itemSection.Text -match $pattern) { $itemName }
					}
				)
				if ($tmpParameterReferences.Count -gt 0) {
					'DESCRIPTION must not mention parameters. Move parameter details to PARAMETER sections.'
				}
				$groupId = $itemSection.GroupId
				if ($null -eq $groupId) { $groupId = 0 }
				if ($hashSynopsisByGroup.ContainsKey($groupId)) {
					$descriptionText = Get-Ps1NormalizedHelpText $itemSection.Text
					foreach ($itemSynopsisText in $hashSynopsisByGroup[$groupId]) {
						$synopsisPhrase = Get-Ps1NormalizedHelpText $itemSynopsisText
						if ($synopsisPhrase -ne '' -and $descriptionText.Contains($synopsisPhrase)) {
							'DESCRIPTION must not repeat SYNOPSIS. Add detail beyond the synopsis instead of copying it.'
							break
						}
					}
				}
			}
			'PARAMETER' {
				$defaultRecord = Get-Ps1ParameterDefaultRecord $itemSection.ParameterRecords $itemSection.Argument
				$hasCodeDefault = ($null -ne $defaultRecord -and $defaultRecord.HasDefault)
				$maxBlanks = if ($hasCodeDefault) { 3 } else { 2 }
				$blankWord = if ($hasCodeDefault) { 'three' } else { 'two' }
				if ($itemSection.Text.Length -ge 100 -or $blankLines -gt $maxBlanks) {
					"PARAMETER $($itemSection.Argument) must be fewer than 100 characters with at most $blankWord blank lines in its prose."
				}
				if ($hasCodeDefault) {
					$defaultPattern = '^(?i)default(?:s)?(?:\s+value)?\s*(?::|to\b|is\b)\s*\S'
					$tmpDefaultHits = @($itemSection.Lines | Where-Object { $_ -match $defaultPattern })
					if ($tmpDefaultHits.Count -eq 0) {
						"PARAMETER $($itemSection.Argument) must document its default value with a trailing Default: ... line."
					}
					else {
						$tmpParagraphs = @()
						$tmpCurrent = @()
						foreach ($itemHelpLine in $itemSection.Lines) {
							if ($itemHelpLine -eq '') {
								if ($tmpCurrent.Count -gt 0) { $tmpParagraphs += , @($tmpCurrent); $tmpCurrent = @() }
							}
							else { $tmpCurrent += $itemHelpLine }
						}
						if ($tmpCurrent.Count -gt 0) { $tmpParagraphs += , @($tmpCurrent) }
						$lastPara = if ($tmpParagraphs.Count -gt 0) { $tmpParagraphs[-1] } else { @() }
						$lastHasDefault = @($lastPara | Where-Object { $_ -match $defaultPattern }).Count -gt 0
						if (-not $lastHasDefault) {
							"Default value explanation must be last in PARAMETER $($itemSection.Argument)."
						}
					}
				}
			}
			'NOTES' {
				$tmpTags = @($itemSection.Lines | Where-Object { $_ -match '^Tags\s*:' })
				$tmpAuthors = @($itemSection.Lines | Where-Object { $_ -match '^Author\s*:\s*\S' })
				$entries = if ($tmpTags.Count -eq 1) { @(($tmpTags[0] -replace '^Tags\s*:\s*', '') -split ',' | ForEach-Object { $_.Trim() }) } else { @() }
				if ($tmpTags.Count -gt 1 -or
					$tmpTags.Count + $tmpAuthors.Count -ne $itemSection.Lines.Count -or
					($tmpTags.Count -eq 1 -and ($entries.Count -lt 2 -or $entries -contains ''))) {
					'NOTES allows an optional Tags: line with multiple comma-separated entries and optional nonempty Author: lines. No other content is allowed.'
				}
			}
			'EXAMPLE' {
				Get-Ps1ExampleMessage -Section $itemSection -Sections $Analysis.HelpSections
			}
		}
		if ($message) {
			[pscustomobject]@{
				RuleName   = 'PSHelp' + [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($itemSection.Name.ToLowerInvariant())
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $itemSection.Line
				Column     = $itemSection.Column
				Message    = $message -join ' '
			}
		}
	}

	$colHelpGroups = @($Analysis.CommentGroups | Where-Object { $_.IsHelp })
	for ($groupIndex = 0; $groupIndex -lt $colHelpGroups.Count; $groupIndex++) {
		$groupId = $groupIndex + 1
		$group = $colHelpGroups[$groupIndex]
		$tmpGroupParameterSections = @($Analysis.HelpSections | Where-Object { $_.GroupId -eq $groupId -and $_.Name -eq 'PARAMETER' })
		foreach ($itemRecord in @($group.ParameterRecords)) {
			if ($null -eq $itemRecord -or -not $itemRecord.HasDefault) { continue }
			$found = $false
			foreach ($itemParameterSection in $tmpGroupParameterSections) {
				$tmpCandidates = @($itemRecord.Name) + @($itemRecord.Aliases)
				foreach ($itemCandidate in $tmpCandidates) {
					if ($null -ne $itemCandidate -and $itemCandidate -ieq $itemParameterSection.Argument) { $found = $true; break }
				}
				if ($found) { break }
			}
			if ($found) { continue }
			$tmpAnchor = @($Analysis.HelpSections | Where-Object { $_.GroupId -eq $groupId }) | Sort-Object Line | Select-Object -First 1
			$anchorLine = if ($null -ne $tmpAnchor) { $tmpAnchor.Line } else { $group.Line }
			$anchorColumn = if ($null -ne $tmpAnchor) { $tmpAnchor.Column } else { $group.Column }
			[pscustomobject]@{
				RuleName   = 'PSHelpParameter'
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $anchorLine
				Column     = $anchorColumn
				Message    = "PARAMETER $($itemRecord.Name) must document its default value with a trailing Default: ... line."
			}
		}
	}
}
