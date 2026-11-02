function Test-Ps1InlineHashtable {
	param($Node)

	if ($Node -is [Management.Automation.Language.HashtableAst]) { $true; return }
	if ($Node -is [Management.Automation.Language.ConvertExpressionAst] -and
		$Node.Child -is [Management.Automation.Language.HashtableAst]) { $true; return }

	if ($Node -is [Management.Automation.Language.ParenExpressionAst]) {
		$colInner = @($Node.Pipeline.PipelineElements)
		if ($colInner.Count -eq 1 -and $colInner[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			Test-Ps1InlineHashtable -Node $colInner[0].Expression
			return
		}
	}

	$false
}

function Get-Ps1HeadersVariableDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$message = 'Assign the headers to a variable first and pass it to -Headers. An inline hashtable inside a multi-line call hides where the hashtable ends.'

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$tmpElements = @($itemCommand.CommandElements)
		for ($index = 0; $index -lt ($tmpElements.Count - 1); $index++) {
			$itemParameter = $tmpElements[$index]
			if ($itemParameter -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if ($itemParameter.ParameterName -ine 'Headers') { continue }

			$itemArgument = $tmpElements[$index + 1]
			if (-not (Test-Ps1InlineHashtable -Node $itemArgument)) { continue }

			New-Ps1Diagnostic $Path 'PSUseVariableForHeaders' $message $itemArgument.Extent
		}
	}
}
