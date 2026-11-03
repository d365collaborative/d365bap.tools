function Test-Ps1ComplexArrayElement {
	param($Node)

	if ($Node -is [Management.Automation.Language.HashtableAst]) { $true; return }
	if ($Node -is [Management.Automation.Language.ScriptBlockExpressionAst]) { $true; return }
	if ($Node -is [Management.Automation.Language.ConvertExpressionAst] -and
		$Node.Child -is [Management.Automation.Language.HashtableAst]) { $true; return }

	$false
}

function Test-Ps1ComplexArrayStatement {
	param($Statement)

	@($Statement.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.HashtableAst] -or
				$Node -is [Management.Automation.Language.ScriptBlockExpressionAst]
			}, $true)).Count -gt 0
}

function Test-Ps1LiteralArrayStatement {
	param($Statement)

	if ($Statement -isnot [Management.Automation.Language.PipelineAst]) { $false; return }
	if ($Statement.PipelineElements.Count -ne 1) { $false; return }
	if ($Statement.PipelineElements[0] -isnot [Management.Automation.Language.CommandExpressionAst]) { $false; return }

	$Statement.PipelineElements[0].Expression -is [Management.Automation.Language.ArrayLiteralAst]
}

function Get-Ps1ComplexArrayElementDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$message = 'Put each complex array element on its own line. A hashtable or scriptblock element makes a crowded line hard to read.'

	$colReportedLiterals = [System.Collections.Generic.List[object]]::new()

	foreach ($itemLiteral in @(Get-Ps1AstNode $Analysis ArrayLiteralAst)) {
		if ($itemLiteral.Parent -is [Management.Automation.Language.CommandAst] -and
			(Get-Command Get-Ps1SelectObjectProjection -ErrorAction Ignore)) {
			$projection = Get-Ps1SelectObjectProjection $itemLiteral.Parent
			if ($null -ne $projection -and $projection.Argument -eq $itemLiteral) { continue }
		}
		$tmpElements = @($itemLiteral.Elements)
		if ($tmpElements.Count -le 1) { continue }

		$tmpComplex = @($tmpElements | Where-Object { Test-Ps1ComplexArrayElement -Node $_ })
		if ($tmpComplex.Count -le 1) { continue }

		for ($index = 0; $index -lt ($tmpComplex.Count - 1); $index++) {
			if ($tmpComplex[$index].Extent.StartLineNumber -ne $tmpComplex[$index + 1].Extent.StartLineNumber) { continue }

			New-Ps1Diagnostic $Path 'PSUseOneComplexArrayElementPerLine' $message $itemLiteral.Extent
			$colReportedLiterals.Add($itemLiteral)
			break
		}
	}

	foreach ($itemSub in @(Get-Ps1AstNode $Analysis ArrayExpressionAst)) {
		if ($itemSub.Extent.StartLineNumber -ne $itemSub.Extent.EndLineNumber) { continue }

		$hasReportedLiteral = $false
		foreach ($itemNested in @(Get-Ps1AstNode $Analysis ArrayLiteralAst $itemSub)) {
			if (-not $colReportedLiterals.Contains($itemNested)) { continue }
			$hasReportedLiteral = $true
			break
		}
		if ($hasReportedLiteral) { continue }

		$tmpComplex = @()
		foreach ($itemStatement in @($itemSub.SubExpression.Statements)) {
			if (Test-Ps1LiteralArrayStatement -Statement $itemStatement) { continue }
			if (-not (Test-Ps1ComplexArrayStatement -Statement $itemStatement)) { continue }
			$tmpComplex += $itemStatement
		}
		if ($tmpComplex.Count -eq 0) { continue }

		New-Ps1Diagnostic $Path 'PSUseOneComplexArrayElementPerLine' $message $itemSub.Extent
	}
}
