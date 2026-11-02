function Get-Ps1TernaryInObjectInitializationDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$message = 'Use a ternary operator for an if expression in an object initializer: <condition> ? <true value> : <else value>.'

	foreach ($itemHashtable in @(Get-Ps1AstNode $Analysis HashtableAst)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item2 -isnot [Management.Automation.Language.IfStatementAst]) { continue }
			if ($null -eq $itemPair.Item2.ElseClause) { continue }

			New-Ps1Diagnostic $Path 'PSUseTernaryInObjectInitialization' $message $itemPair.Item2.Extent
		}
	}
}
