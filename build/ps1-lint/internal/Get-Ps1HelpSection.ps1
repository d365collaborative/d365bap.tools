function Get-Ps1HelpSection {
	param([hashtable] $Analysis)

	$groupId = 0
	foreach ($comment in $Analysis.CommentGroups) {
		if (-not $comment.IsHelp) { continue }
		$groupId++
		$text = $comment.Text
		$isBlock = $text.StartsWith('<#')
		if ($isBlock) { $text = $text.Substring(2, $text.Length - 4) }
		$lines = $text -split '\r\n|\n|\r'
		$parameterNames = @($comment.ParameterNames) + @(
			[regex]::Matches($text, '(?im)^\s*(?:#\s*)?\.PARAMETER\s+(\S+)\s*$') |
			ForEach-Object { $_.Groups[1].Value }
		)
		$parameterRecords = @($comment.ParameterRecords)
		$section = $null
		for ($index = 0; $index -le $lines.Count; $index++) {
			$line = if ($index -lt $lines.Count) { $lines[$index] } else { $null }
			$column = if ($index -eq 0) { $comment.Column + $(if ($isBlock) { 2 } else { 0 }) } else { 1 }
			if (-not $isBlock -and $null -ne $line) {
				$prefix = [regex]::Match($line, '^\s*# ?').Length
				$column += $prefix
				$line = $line.Substring($prefix)
			}
			$isHeader = $null -ne $line -and $line -match '^\s*\.(?<Name>\w+)(?:\s+(?<Argument>.*?))?\s*$'
			if ($isHeader -or $index -eq $lines.Count) {
				if ($null -ne $section) {
					$first = 0
					$last = $section.Lines.Count - 1
					while ($first -le $last -and $section.Lines[$first] -eq '') { $first++ }
					while ($last -ge $first -and $section.Lines[$last] -eq '') { $last-- }
					$content = @(if ($first -le $last) { $section.Lines.GetRange($first, $last - $first + 1) })
					[pscustomobject]@{
						Name             = $section.Name
						Argument         = $section.Argument
						Line             = $section.Line
						Column           = $section.Column
						Lines            = @($content)
						Text             = $content -join "`n"
						ParameterNames   = $parameterNames
						GroupId          = $groupId
						CommentLine      = $comment.Line
						CommentColumn    = $comment.Column
						ParameterRecords = @($parameterRecords)
						CommandName      = $comment.CommandName
					}
				}
				$section = if ($isHeader) {
					@{ Name = $Matches.Name.ToUpperInvariant(); Argument = $Matches.Argument; Line = $comment.Line + $index; Column = $column + $line.IndexOf('.'); Lines = [Collections.Generic.List[string]]::new() }
				}
				else { $null }
			}
			elseif ($null -ne $section) { $section.Lines.Add($line.Trim()) }
		}
	}
}
