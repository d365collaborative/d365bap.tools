function New-Ps1LoopAppendDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidLoopAppend'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1LoopAppendDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemLoop in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
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

		New-Ps1LoopAppendDiagnostic -Path $Path -Extent $itemLoop.Extent -Message 'This foreach only copies the loop variable into another collection. Use AddRange, assign the source directly when the loop is not paginating, or UnionWith for a set.'
	}
}
