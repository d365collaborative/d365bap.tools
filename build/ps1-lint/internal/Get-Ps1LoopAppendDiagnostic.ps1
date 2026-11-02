function Get-Ps1LoopAppendDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemLoop in @(Get-Ps1AstNode $Analysis ForEachStatementAst)) {
		$tmpStatements = @($itemLoop.Body.Statements)
		if ($tmpStatements.Count -ne 1) { continue }

		$statement = $tmpStatements[0]
		if ($statement -isnot [Management.Automation.Language.PipelineAst]) { continue }

		$tmpElements = @($statement.PipelineElements)
		if ($tmpElements.Count -ne 1) { continue }

		$element = $tmpElements[0]
		if ($element -isnot [Management.Automation.Language.CommandExpressionAst]) { continue }

		$invoke = $element.Expression
		if ($invoke -isnot [Management.Automation.Language.InvokeMemberExpressionAst]) { continue }
		if ($invoke.Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($invoke.Member.Value -cne 'Add') { continue }
		if ($invoke.Expression -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }

		$tmpArguments = @($invoke.Arguments)
		if ($tmpArguments.Count -ne 1) { continue }
		if ($tmpArguments[0] -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
		if ($tmpArguments[0].VariablePath.UserPath -ne $itemLoop.Variable.VariablePath.UserPath) { continue }

		New-Ps1Diagnostic $Path 'PSAvoidLoopAppend' 'This foreach only copies the loop variable into another collection. Use AddRange, assign the source directly when the loop is not paginating, or UnionWith for a set.' $itemLoop.Extent
	}
}
