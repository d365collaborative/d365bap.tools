function Get-Ps1ModuleSplattingDiagnostic {
	param([hashtable] $Analysis, [hashtable] $Worker)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$hashFunctions = $null
	$indexLoaded = $false
	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$tmpSplats = @($itemCommand.CommandElements | Where-Object {
				$_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.Splatted
			})
		if ($tmpSplats.Count -eq 0) { continue }
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) {
			New-Ps1Diagnostic $Path 'PSAvoidSplattingForModuleCommands' 'Unsupported splatted command target. Use a literal target or explicit named arguments.' $itemCommand.Extent
			continue
		}

		$parts = $commandName -split '\\'
		if ($parts.Count -gt 1 -and $parts[0] -ine 'd365bap.tools') { continue }
		$shortName = $parts[-1]
		if (-not $indexLoaded) {
			$indexLoaded = $true
			$moduleRoot = Get-Ps1ModuleRoot -Path $Path
			if (-not [string]::IsNullOrEmpty($moduleRoot)) {
				if ($null -eq $Worker) { $Worker = Get-Ps1AnalysisWorker }
				$hashFunctions = (Get-Ps1RepositoryIndex -ModuleRoot $moduleRoot `
						-Worker $Worker).Commands
			}
		}
		if ($null -eq $hashFunctions) { continue }
		if (-not $hashFunctions.ContainsKey($shortName.ToLowerInvariant())) { continue }

		foreach ($itemElement in $tmpSplats) {
			$splatName = '@' + $itemElement.VariablePath.UserPath
			New-Ps1Diagnostic $Path 'PSAvoidSplattingForModuleCommands' "Do not splat $splatName into the module command $shortName. Pass its parameters explicitly." $itemElement.Extent
		}
	}
}
