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

function New-Ps1FormattedUrlDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseFormattedUrl'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
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

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemString in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ExpandableStringExpressionAst] }, $true)) {
		if ($itemString.StringConstantType -in @('SingleQuotedHereString', 'DoubleQuotedHereString')) { continue }
		if ($itemString.Value -notmatch $script:Ps1UrlTextPattern) { continue }

		New-Ps1FormattedUrlDiagnostic -Path $Path `
			-Extent $itemString.Extent `
			-Message 'Build URL strings with the format operator (-f), not string interpolation.'
	}

	foreach ($itemBinary in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.BinaryExpressionAst] -and "$($Node.Operator)" -eq 'Format' }, $true)) {
		if ($itemBinary.Left -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($itemBinary.Left.StringConstantType -in @('SingleQuotedHereString', 'DoubleQuotedHereString')) { continue }
		if ($itemBinary.Left.Value -notmatch $script:Ps1UrlTextPattern) { continue }

		if (-not (Test-Ps1OrderedFormatString -Value $itemBinary.Left.Value)) {
			New-Ps1FormattedUrlDiagnostic -Path $Path `
				-Extent $itemBinary.Extent `
				-Message 'Start URL format placeholders at {0} and keep them in left-to-right order; a later placeholder cannot reappear before an earlier one.'
		}

		$tmpInputs = if ($itemBinary.Right -is [Management.Automation.Language.ArrayLiteralAst]) { @($itemBinary.Right.Elements) } else { @($itemBinary.Right) }

		$formatInline = $false
		foreach ($itemToken in @($Analysis.Tokens)) {
			if ($itemToken.Kind -ne [System.Management.Automation.Language.TokenKind]::Format) { continue }
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
			New-Ps1FormattedUrlDiagnostic -Path $Path `
				-Extent $itemBinary.Extent `
				-Message 'Put -f on its own continuation line; when the URL format has more than one input, put each input on its own line.'
		}
	}

	foreach ($itemBinary in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.BinaryExpressionAst] -and "$($Node.Operator)" -eq 'Plus' }, $true)) {
		foreach ($itemSide in @($itemBinary.Left, $itemBinary.Right)) {
			if (-not (Test-Ps1UrlStringValue -Node $itemSide)) { continue }
			New-Ps1FormattedUrlDiagnostic -Path $Path `
				-Extent $itemBinary.Extent `
				-Message 'Build URL strings with the format operator (-f), not string concatenation.'
			break
		}
	}
}
