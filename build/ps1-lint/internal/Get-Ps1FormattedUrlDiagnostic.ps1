$script:Ps1UrlTextPattern = '(?i)https?://|api-version='

function Test-Ps1UrlStringValue {
	param($Node)

	$value = $Node
	while ($true) {
		if ($value -is [Management.Automation.Language.ParenExpressionAst]) {
			$value = $value.Pipeline
			continue
		}
		if ($value -is [Management.Automation.Language.PipelineAst] -and
			$value.PipelineElements.Count -eq 1 -and
			$value.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			$value = $value.PipelineElements[0].Expression
			continue
		}
		break
	}

	if ($value -isnot [Management.Automation.Language.StringConstantExpressionAst]) { $false; return }
	if ($value.StringConstantType -in @('SingleQuotedHereString', 'DoubleQuotedHereString')) { $false; return }
	$value.Value -match $script:Ps1UrlTextPattern
}

function Test-Ps1OrderedFormatString {
	param([string] $Value)

	$colIndexes = @([regex]::Matches($Value, '\{(\d+)(?::[^}]*)?\}') | ForEach-Object { [int]$_.Groups[1].Value })
	if ($colIndexes.Count -eq 0) { $true; return }
	if ($colIndexes[0] -ne 0) { $false; return }

	$previous = 0
	foreach ($itemIndex in $colIndexes) {
		if ($itemIndex -lt $previous) { $false; return }
		$previous = $itemIndex
	}
	$true
}

function Get-Ps1FormattedUrlDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemString in @(Get-Ps1AstNode $Analysis ExpandableStringExpressionAst)) {
		if ($itemString.StringConstantType -in @('SingleQuotedHereString', 'DoubleQuotedHereString')) { continue }
		if ($itemString.Value -notmatch $script:Ps1UrlTextPattern) { continue }

		New-Ps1Diagnostic $Path 'PSUseFormattedUrl' 'Build URL strings with the format operator (-f), not string interpolation.' $itemString.Extent
	}

	$colBinary = @(Get-Ps1AstNode $Analysis BinaryExpressionAst)
	$colFormatTokens = @(Get-Ps1TokenNode $Analysis Format)

	foreach ($itemBinary in $colBinary) {
		if ("$($itemBinary.Operator)" -ne 'Format') { continue }
		if ($itemBinary.Left -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($itemBinary.Left.StringConstantType -in @('SingleQuotedHereString', 'DoubleQuotedHereString')) { continue }
		if ($itemBinary.Left.Value -notmatch $script:Ps1UrlTextPattern) { continue }

		if (-not (Test-Ps1OrderedFormatString -Value $itemBinary.Left.Value)) {
			New-Ps1Diagnostic $Path 'PSUseFormattedUrl' 'Start URL format placeholders at {0} and keep them in left-to-right order; a later placeholder cannot reappear before an earlier one.' $itemBinary.Extent
		}

		$tmpInputs = if ($itemBinary.Right -is [Management.Automation.Language.ArrayLiteralAst]) { @($itemBinary.Right.Elements) } else { @($itemBinary.Right) }

		$formatInline = $false
		foreach ($itemToken in $colFormatTokens) {
			if ($itemToken.Extent.StartOffset -lt $itemBinary.Left.Extent.EndOffset) { continue }
			if ($itemToken.Extent.StartOffset -gt $itemBinary.Extent.EndOffset) { continue }
			$formatInline = $itemToken.Extent.StartLineNumber -eq $itemBinary.Left.Extent.EndLineNumber
			break
		}

		$tmpLines = @{}
		foreach ($itemInput in $tmpInputs) {
			$line = $itemInput.Extent.StartLineNumber
			if (-not $tmpLines.ContainsKey($line)) { $tmpLines[$line] = 0 }
			$tmpLines[$line]++
		}
		$hasCrowdedLine = @($tmpLines.Keys | Where-Object { $tmpLines[$_] -gt 1 }).Count -gt 0

		if ($formatInline -or $hasCrowdedLine) {
			New-Ps1Diagnostic $Path 'PSUseFormattedUrl' 'Put -f on its own continuation line; when the URL format has more than one input, put each input on its own line.' $itemBinary.Extent
		}
	}

	foreach ($itemBinary in $colBinary) {
		if ("$($itemBinary.Operator)" -ne 'Plus') { continue }
		foreach ($itemSide in @($itemBinary.Left, $itemBinary.Right)) {
			if (-not (Test-Ps1UrlStringValue -Node $itemSide)) { continue }
			New-Ps1Diagnostic $Path 'PSUseFormattedUrl' 'Build URL strings with the format operator (-f), not string concatenation.' $itemBinary.Extent
			break
		}
	}
}
