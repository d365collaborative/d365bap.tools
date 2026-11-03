function Get-Ps1LoopAppendExpression {
	param($Expression)
	while ($null -ne $Expression) {
		if ($Expression -is [Management.Automation.Language.ParenExpressionAst]) { $Expression = $Expression.Pipeline; continue }
		if ($Expression -is [Management.Automation.Language.PipelineAst]) {
			if ($Expression.PipelineElements.Count -ne 1 -or $Expression.Background) { return }
			$Expression = $Expression.PipelineElements[0]; continue
		}
		if ($Expression -is [Management.Automation.Language.CommandExpressionAst]) {
			if ($Expression.Redirections.Count -gt 0) { return }
			$Expression = $Expression.Expression; continue
		}
		$Expression; return
	}
}

function Get-Ps1LoopAppendDiagnostic {
	param([hashtable] $Analysis)
	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }
	foreach ($itemLoop in @(Get-Ps1AstNode $Analysis ForEachStatementAst)) {
		$tmpStatements = @($itemLoop.Body.Statements)
		if ($tmpStatements.Count -ne 1 -or $itemLoop.Body.Traps.Count -gt 0) { continue }
		$invoke = Get-Ps1LoopAppendExpression $tmpStatements[0]
		if ($invoke -isnot [Management.Automation.Language.InvokeMemberExpressionAst] -or $invoke.Static) { continue }
		if ($invoke.Member -isnot [Management.Automation.Language.StringConstantExpressionAst] -or $invoke.Member.Value -ine 'Add') { continue }
		if ($invoke.Expression -isnot [Management.Automation.Language.VariableExpressionAst] -or $invoke.Arguments.Count -ne 1) { continue }
		$receiver = $invoke.Expression.VariablePath.UserPath
		if ($receiver -ieq $itemLoop.Variable.VariablePath.UserPath) { continue }
		$argument = Get-Ps1LoopAppendExpression $invoke.Arguments[0]
		if ($argument -isnot [Management.Automation.Language.VariableExpressionAst] -or $argument.VariablePath.UserPath -ine $itemLoop.Variable.VariablePath.UserPath) { continue }
		$source = Get-Ps1LoopAppendExpression $itemLoop.Condition
		if ($source -isnot [Management.Automation.Language.VariableExpressionAst] -or $source.VariablePath.UserPath -ieq $receiver) { continue }
		$block = $itemLoop.Parent
		if ($block -isnot [Management.Automation.Language.StatementBlockAst] -and $block -isnot [Management.Automation.Language.NamedBlockAst]) { continue }
		$tmpPreceding = @($block.Statements | Where-Object { $_.Extent.EndOffset -le $itemLoop.Extent.StartOffset })
		if ($tmpPreceding.Count -eq 0) { continue }
		$assignment = $tmpPreceding[-1]
		if ($assignment -isnot [Management.Automation.Language.AssignmentStatementAst] -or $assignment.Operator -ne 'Equals') { continue }
		if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst] -or $assignment.Left.VariablePath.UserPath -ine $receiver) { continue }
		$constructor = Get-Ps1LoopAppendExpression $assignment.Right
		if ($constructor -isnot [Management.Automation.Language.InvokeMemberExpressionAst] -or -not $constructor.Static -or $constructor.Arguments.Count -ne 0) { continue }
		if ($constructor.Member -isnot [Management.Automation.Language.StringConstantExpressionAst] -or $constructor.Member.Value -ine 'new') { continue }
		if ($constructor.Expression -isnot [Management.Automation.Language.TypeExpressionAst] -or $constructor.Expression.TypeName.FullName -notmatch '^(?:System\.)?Collections\.Generic\.List\[[\w.]+\]$') { continue }
		New-Ps1Diagnostic $Analysis.Path 'PSAvoidLoopAppend' 'Review whether AddRange can replace this generic List copy loop while preserving the source and behavior.' $itemLoop.Extent
	}
}
