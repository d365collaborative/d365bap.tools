function Get-Ps1IfConditionExpression {
	param($Condition)

	$tmp = $Condition
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
		$tmp
		return
	}
}

function Get-Ps1IfConditionOperand {
	param($Expression, [string] $Operator, [System.Collections.Generic.List[object]] $Operands)

	if ($Expression -is [Management.Automation.Language.BinaryExpressionAst] -and
		"$($Expression.Operator)" -eq $Operator) {
		Get-Ps1IfConditionOperand -Expression $Expression.Left `
			-Operator $Operator `
			-Operands $Operands
		Get-Ps1IfConditionOperand -Expression $Expression.Right `
			-Operator $Operator `
			-Operands $Operands
		return
	}

	$Operands.Add($Expression)
}

function Test-Ps1IfConditionOperatorLine {
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
		if (-not (Test-Ps1IfConditionOperatorLine -Expression $itemChild `
					-Tokens $Tokens)) { $false; return }
	}

	$true
}

function Test-Ps1IfConditionExpression {
	param($Expression, $Tokens)

	$tmp = $Expression
	if ($tmp -is [Management.Automation.Language.ParenExpressionAst]) {
		Test-Ps1IfConditionExpression -Expression (Get-Ps1IfConditionExpression -Condition $tmp.Pipeline) `
			-Tokens $Tokens
		return
	}
	if ($tmp -isnot [Management.Automation.Language.BinaryExpressionAst]) { $true; return }

	$operator = "$($tmp.Operator)"
	if ($operator -notin @('And', 'Or')) { $true; return }

	if (-not (Test-Ps1IfConditionOperatorLine -Expression $tmp `
				-Tokens $Tokens)) { $false; return }

	$colOperands = [System.Collections.Generic.List[object]]::new()
	Get-Ps1IfConditionOperand -Expression $tmp `
		-Operator $operator `
		-Operands $colOperands

	for ($index = 0; $index -lt $colOperands.Count; $index++) {
		$itemOperand = $colOperands[$index]
		if ($index -gt 0 -and $itemOperand.Extent.StartLineNumber -eq $colOperands[$index - 1].Extent.StartLineNumber) { $false; return }
		if ($itemOperand -isnot [Management.Automation.Language.ParenExpressionAst]) { $false; return }
		if (-not (Test-Ps1IfConditionExpression -Expression (Get-Ps1IfConditionExpression -Condition $itemOperand.Pipeline) `
					-Tokens $Tokens)) { $false; return }
	}

	$true
}

function New-Ps1MultilineIfConditionDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseMultilineIfCondition'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1MultilineIfConditionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$message = 'Start each -and / -or line with the operator: (<test>) ` then a new line with -and (<test>). The operator is leftmost to show the logic split.'

	foreach ($itemIf in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.IfStatementAst] }, $true)) {
		foreach ($itemClause in $itemIf.Clauses) {
			$tmpCondition = Get-Ps1IfConditionExpression -Condition $itemClause.Item1
			if (Test-Ps1IfConditionExpression -Expression $tmpCondition `
					-Tokens $Analysis.Tokens) { continue }

			New-Ps1MultilineIfConditionDiagnostic -Path $Path `
				-Extent $itemClause.Item1.Extent `
				-Message $message
		}
	}
}
