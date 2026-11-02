function Get-Ps1BooleanExpression {
	param($Expression)

	$tmp = $Expression
	while ($true) {
		if ($tmp -is [Management.Automation.Language.PipelineAst] -and
			$tmp.PipelineElements.Count -eq 1 -and
			$tmp.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			$tmp = $tmp.PipelineElements[0].Expression
			continue
		}
		if ($tmp -is [Management.Automation.Language.ParenExpressionAst]) {
			$tmp = $tmp.Pipeline
			continue
		}
		if ($tmp -is [Management.Automation.Language.UnaryExpressionAst] -and
			"$($tmp.TokenKind)" -eq 'Not') {
			$tmp = $tmp.Child
			continue
		}
		$tmp
		return
	}
}

function Get-Ps1BooleanOperand {
	param($Expression, [string] $Operator, [System.Collections.Generic.List[object]] $Operands)

	if ($Expression -is [Management.Automation.Language.BinaryExpressionAst] -and
		"$($Expression.Operator)" -eq $Operator) {
		Get-Ps1BooleanOperand -Expression $Expression.Left `
			-Operator $Operator `
			-Operands $Operands
		Get-Ps1BooleanOperand -Expression $Expression.Right `
			-Operator $Operator `
			-Operands $Operands
		return
	}

	$Operands.Add($Expression)
}

function Test-Ps1BooleanOperatorLine {
	param($Expression, $Tokens)

	$tmpToken = $null
	foreach ($itemToken in $Tokens) {
		if ($itemToken.Kind -ne $Expression.Operator) { continue }
		if ($itemToken.Extent.StartOffset -lt $Expression.Left.Extent.EndOffset) { continue }
		if ($itemToken.Extent.EndOffset -gt $Expression.Right.Extent.StartOffset) { continue }
		$tmpToken = $itemToken
		break
	}
	if ($null -eq $tmpToken) { $false; return }
	if ($tmpToken.Extent.StartLineNumber -eq $Expression.Left.Extent.EndLineNumber) { $false; return }

	foreach ($itemChild in @($Expression.Left, $Expression.Right)) {
		if ($itemChild -isnot [Management.Automation.Language.BinaryExpressionAst]) { continue }
		if ("$($itemChild.Operator)" -notin @('And', 'Or')) { continue }
		if (-not (Test-Ps1BooleanOperatorLine -Expression $itemChild `
					-Tokens $Tokens)) { $false; return }
	}

	$true
}

function Test-Ps1BooleanLayout {
	param($Expression, $Tokens)

	$tmp = Get-Ps1BooleanExpression -Expression $Expression
	if ($tmp -isnot [Management.Automation.Language.BinaryExpressionAst]) { $true; return }

	$operator = "$($tmp.Operator)"
	if ($operator -notin @('And', 'Or')) { $true; return }

	if (-not (Test-Ps1BooleanOperatorLine -Expression $tmp `
				-Tokens $Tokens)) { $false; return }

	$colOperands = [System.Collections.Generic.List[object]]::new()
	Get-Ps1BooleanOperand -Expression $tmp `
		-Operator $operator `
		-Operands $colOperands

	for ($index = 0; $index -lt $colOperands.Count; $index++) {
		$itemOperand = $colOperands[$index]
		if ($index -gt 0 -and $itemOperand.Extent.StartLineNumber -eq $colOperands[$index - 1].Extent.StartLineNumber) { $false; return }
		if ($itemOperand -isnot [Management.Automation.Language.ParenExpressionAst]) { $false; return }
		if (-not (Test-Ps1BooleanLayout -Expression $itemOperand `
					-Tokens $Tokens)) { $false; return }
	}

	$true
}

function Get-Ps1WhereObjectFilter {
	param($Command)

	$name = "$($Command.GetCommandName())"
	if ([string]::IsNullOrWhiteSpace($name)) { return }

	# Strip a module or scope qualifier before matching the cmdlet and its
	# standard aliases.
	$leaf = @($name -split '[\\:]')[-1]
	if ($leaf -notin @('Where-Object', 'where', '?')) { return }

	$colElements = @($Command.CommandElements)
	for ($index = 1; $index -lt $colElements.Count; $index++) {
		$itemElement = $colElements[$index]
		if ($itemElement -is [Management.Automation.Language.CommandParameterAst]) {
			if ("$($itemElement.ParameterName)" -ne 'FilterScript') { continue }
			# `-FilterScript:{ ... }` binds the script block to the parameter
			# itself instead of adding a separate command element.
			if ($itemElement.Argument -is [Management.Automation.Language.ScriptBlockExpressionAst]) {
				$itemElement.Argument
				return
			}
			# A named -FilterScript binds only the argument that follows it. A
			# variable or other expression there cannot be checked statically.
			if ($index + 1 -ge $colElements.Count) { return }
			$itemArgument = $colElements[$index + 1]
			if ($itemArgument -is [Management.Automation.Language.ScriptBlockExpressionAst]) { $itemArgument; return }
			return
		}
		if ($itemElement -is [Management.Automation.Language.ScriptBlockExpressionAst]) { $itemElement; return }
	}
}

function Test-Ps1WhereObjectFilter {
	param($Filter, $Tokens)

	$hasViolation = $false
	$colBlocks = @($Filter.ScriptBlock.BeginBlock, $Filter.ScriptBlock.ProcessBlock, $Filter.ScriptBlock.EndBlock)
	foreach ($itemBlock in $colBlocks) {
		if ($null -eq $itemBlock) { continue }
		foreach ($itemStatement in $itemBlock.Statements) {
			if ($itemStatement -isnot [Management.Automation.Language.PipelineAst]) { continue }
			if (Test-Ps1BooleanLayout -Expression $itemStatement `
					-Tokens $Tokens) { continue }
			$hasViolation = $true
		}
	}

	$hasViolation
}

function Get-Ps1MultilineIfConditionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$message = 'Start each -and / -or line with the operator: (<test>) ` then a new line with -and (<test>). The operator is leftmost to show the logic split.'

	foreach ($itemIf in @(Get-Ps1AstNode $Analysis IfStatementAst)) {
		foreach ($itemClause in $itemIf.Clauses) {
			if (Test-Ps1BooleanLayout -Expression $itemClause.Item1 `
					-Tokens $Analysis.Tokens) { continue }

			New-Ps1Diagnostic $Path 'PSUseMultilineIfCondition' $message $itemClause.Item1.Extent
		}
	}

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$itemFilter = Get-Ps1WhereObjectFilter -Command $itemCommand
		if ($null -eq $itemFilter) { continue }
		if (-not (Test-Ps1WhereObjectFilter -Filter $itemFilter `
					-Tokens $Analysis.Tokens)) { continue }

		New-Ps1Diagnostic $Path 'PSUseMultilineIfCondition' $message $itemFilter.Extent
	}
}
