function Test-Ps1MultilineIfBlock {
	param($Block)

	$colStatements = @($Block.Statements)
	if ($colStatements.Count -eq 0) {
		$Block.Extent.StartLineNumber -ne $Block.Extent.EndLineNumber
		return
	}
	if ($colStatements[0].Extent.StartLineNumber -eq $Block.Extent.StartLineNumber) { $false; return }
	if ($colStatements[-1].Extent.EndLineNumber -eq $Block.Extent.EndLineNumber) { $false; return }

	$true
}

function Test-Ps1MultilineIfStatement {
	param($If)

	foreach ($itemClause in $If.Clauses) {
		if (-not (Test-Ps1MultilineIfBlock -Block $itemClause.Item2)) { $false; return }
	}

	if ($null -eq $If.ElseClause) { $true; return }

	$tmpThenBlock = $If.Clauses[-1].Item2
	if ($If.ElseClause.Extent.StartLineNumber -eq $tmpThenBlock.Extent.EndLineNumber) { $false; return }

	$tmpElse = $If.ElseClause
	if ($tmpElse -is [Management.Automation.Language.IfStatementAst]) {
		Test-Ps1MultilineIfStatement -If $tmpElse
		return
	}
	if ($tmpElse -is [Management.Automation.Language.StatementBlockAst]) {
		Test-Ps1MultilineIfBlock -Block $tmpElse
		return
	}

	$false
}

function Get-Ps1MultilineIfExpressionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$message = 'Break the if/else branches onto separate lines. A declared variable assigned in an if statement or a ternary operator is also allowed.'

	foreach ($itemAssignment in @(Get-Ps1AstNode $Analysis AssignmentStatementAst)) {
		if ($itemAssignment.Right -isnot [Management.Automation.Language.IfStatementAst]) { continue }
		if ($null -eq $itemAssignment.Right.ElseClause) { continue }
		if (Test-Ps1MultilineIfStatement -If $itemAssignment.Right) { continue }

		New-Ps1Diagnostic $Path 'PSUseMultilineIfExpression' $message $itemAssignment.Right.Extent
	}
}
