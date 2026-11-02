function Get-Ps1OneParameterPerLineDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleOrLintTooling')) { return }

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$tmpLines = @{}
		foreach ($itemElement in $itemCommand.CommandElements) {
			if ($itemElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			$line = $itemElement.Extent.StartLineNumber
			if (-not $tmpLines.ContainsKey($line)) { $tmpLines[$line] = 0 }
			$tmpLines[$line]++
		}

		$hasCrowdedLine = @($tmpLines.Keys | Where-Object { $tmpLines[$_] -gt 1 }).Count -gt 0
		if (-not $hasCrowdedLine) { continue }

		New-Ps1Diagnostic $Path 'PSUseOneParameterPerLine' 'A command with more than one parameter puts each parameter on its own line. The first parameter may stay on the command line; every later parameter gets a new line.' $itemCommand.Extent
	}
}
