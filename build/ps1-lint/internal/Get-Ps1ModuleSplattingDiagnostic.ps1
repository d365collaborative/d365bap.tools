function Get-Ps1ModuleSplattingDiagnostic {
	param([hashtable] $Analysis, [hashtable] $Worker)
	$Path = $Analysis.Path
	if ($null -eq $Worker) { $Worker = Get-Ps1AnalysisWorker }

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$moduleRoot = Get-Ps1ModuleRoot -Path $Path
	if ([string]::IsNullOrEmpty($moduleRoot)) { return }

	$hashFunctions = (Get-Ps1RepositoryIndex -ModuleRoot $moduleRoot `
			-Worker $Worker).Commands

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }

		$parts = $commandName -split '\\'
		if ($parts.Count -gt 1 -and $parts[0] -ine 'd365bap.tools') { continue }
		$shortName = $parts[-1]
		if (-not $hashFunctions.ContainsKey($shortName.ToLowerInvariant())) { continue }

		foreach ($itemElement in $itemCommand.CommandElements) {
			if ($itemElement -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
			if (-not $itemElement.Splatted) { continue }

			$splatName = '@' + $itemElement.VariablePath.UserPath
			New-Ps1Diagnostic $Path 'PSAvoidSplattingForModuleCommands' "Do not splat $splatName into the module command $shortName. Pass its parameters explicitly." $itemElement.Extent
		}
	}
}
