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

function New-Ps1MultilineIfExpressionDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseMultilineIfExpression'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1MultilineIfExpressionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$message = 'Break the if/else branches onto separate lines. A declared variable assigned in an if statement or a ternary operator is also allowed.'

	foreach ($itemAssignment in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
		if ($itemAssignment.Right -isnot [Management.Automation.Language.IfStatementAst]) { continue }
		if ($null -eq $itemAssignment.Right.ElseClause) { continue }
		if (Test-Ps1MultilineIfStatement -If $itemAssignment.Right) { continue }

		New-Ps1MultilineIfExpressionDiagnostic -Path $Path `
			-Extent $itemAssignment.Right.Extent `
			-Message $message
	}

	foreach ($itemHashtable in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.HashtableAst] }, $true)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item2 -isnot [Management.Automation.Language.IfStatementAst]) { continue }
			if ($null -eq $itemPair.Item2.ElseClause) { continue }
			if (Test-Ps1MultilineIfStatement -If $itemPair.Item2) { continue }

			New-Ps1MultilineIfExpressionDiagnostic -Path $Path `
				-Extent $itemPair.Item2.Extent `
				-Message $message
		}
	}
}
