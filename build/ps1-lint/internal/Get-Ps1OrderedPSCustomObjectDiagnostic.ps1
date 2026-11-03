function Get-Ps1OrderedChild {
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
	$value
}

function Get-Ps1OrderedPSCustomObjectDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemConvert in @(Get-Ps1AstNode $Analysis ConvertExpressionAst)) {
		if ($itemConvert.Type.TypeName.FullName -notmatch '(?i)^(system\.management\.automation\.)?pscustomobject$') { continue }

		$child = Get-Ps1OrderedChild -Node $itemConvert.Child
		if ($child -is [Management.Automation.Language.ConvertExpressionAst] -and
			$child.Type.TypeName.FullName -ieq 'ordered') {
			$child = Get-Ps1OrderedChild -Node $child.Child
			if ($child -is [Management.Automation.Language.HashtableAst]) { continue }
		}
		while ($child -is [Management.Automation.Language.ConvertExpressionAst]) {
			$child = Get-Ps1OrderedChild -Node $child.Child
		}
		if ($child -isnot [Management.Automation.Language.HashtableAst]) { continue }

		New-Ps1Diagnostic $Path 'PSUseOrderedPSCustomObject' 'Build the object through [ordered] so property order is explicit: [pscustomobject][ordered]@{ ... }.' $itemConvert.Extent
	}
}
