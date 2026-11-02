function Get-Ps1EmptyLineAfterContinuationDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$colContinuations = @(Get-Ps1TokenNode $Analysis LineContinuation)
	if ($colContinuations.Count -eq 0) { return }

	foreach ($itemBlock in @(Get-Ps1AstNode $Analysis NamedBlockAst, StatementBlockAst)) {
		$tmpStatements = @($itemBlock.Statements)
		for ($index = 0; $index -lt $tmpStatements.Count - 1; $index++) {
			$current = $tmpStatements[$index]
			$next = $tmpStatements[$index + 1]
			if ($next.Extent.StartLineNumber -ne ($current.Extent.EndLineNumber + 1)) { continue }

			$continuationLine = $current.Extent.EndLineNumber - 1
			$hasContinuation = $false
			foreach ($itemContinuation in $colContinuations) {
				if ($itemContinuation.Extent.StartLineNumber -ne $continuationLine) { continue }
				if ($itemContinuation.Extent.StartOffset -lt $current.Extent.StartOffset) { continue }
				if ($itemContinuation.Extent.EndOffset -gt $current.Extent.EndOffset) { continue }
				$hasContinuation = $true
				break
			}
			if (-not $hasContinuation) { continue }

			New-Ps1Diagnostic $Path 'PSUseEmptyLineAfterContinuation' 'Add an empty line after the line continuation so the next statement is clearly separate.' $next.Extent
		}
	}
}
