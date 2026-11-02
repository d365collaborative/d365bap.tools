function Test-Ps1NullOperand {
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

	$value -is [Management.Automation.Language.VariableExpressionAst] -and
	$value.VariablePath.UserPath -ieq 'null'
}

function Get-Ps1NotEqualNullDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemBinary in @(Get-Ps1AstNode $Analysis BinaryExpressionAst)) {
		if ("$($itemBinary.Operator)" -notin @('Ine', 'Cne')) { continue }
		if (-not (Test-Ps1NullOperand -Node $itemBinary.Left)) { continue }

		New-Ps1Diagnostic $Path 'PSAvoidNotEqualNull' 'Do not test against $null with -ne or -cne. Use -Not ($null -eq <expression>) instead.' $itemBinary.Extent
	}
}
