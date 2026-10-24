function Get-Ps1HelpDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

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
			}
			'PARAMETER' {
				if ($section.Text.Length -ge 100 -or $blankLines -gt 2) {
					"PARAMETER $($section.Argument) must be fewer than 100 characters with at most two blank lines in its prose."
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
}
