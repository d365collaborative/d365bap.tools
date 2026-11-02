function Get-Ps1ModuleFunctionIndex {
	param([string] $ModuleRoot)

	if ($null -eq $script:Ps1ModuleFunctionIndex) { $script:Ps1ModuleFunctionIndex = @{} }
	$cacheKey = $ModuleRoot.ToLowerInvariant()
	if ($script:Ps1ModuleFunctionIndex.ContainsKey($cacheKey)) {
		$script:Ps1ModuleFunctionIndex[$cacheKey]
		return
	}

	$hashFunctions = @{}
	foreach ($itemFile in @(Get-ChildItem -LiteralPath $ModuleRoot `
				-Recurse `
				-File)) {
		if ($itemFile.Extension -notin @('.ps1', '.psm1')) { continue }
		$normalized = $itemFile.FullName -replace '\\', '/'
		if ($normalized -match '/tests/') { continue }
		if ($normalized -match '/internal/tepp/') { continue }

		$tokens = $null
		$parseErrors = $null
		$ast = [Management.Automation.Language.Parser]::ParseFile($itemFile.FullName, [ref]$tokens, [ref]$parseErrors)
		if (@($parseErrors).Count -gt 0) { continue }

		foreach ($itemFunction in $ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
			$hashFunctions[$itemFunction.Name.ToLowerInvariant()] = $itemFunction.Name
		}
	}

	$script:Ps1ModuleFunctionIndex[$cacheKey] = $hashFunctions
	$hashFunctions
}

function New-Ps1ModuleSplattingDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidSplattingForModuleCommands'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ModuleSplattingDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$moduleRoot = Get-Ps1ModuleRoot -Path $Path
	if ([string]::IsNullOrEmpty($moduleRoot)) { return }

	$hashFunctions = Get-Ps1ModuleFunctionIndex -ModuleRoot $moduleRoot

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
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
			New-Ps1ModuleSplattingDiagnostic -Path $Path `
				-Extent $itemElement.Extent `
				-Message "Do not splat $splatName into the module command $shortName. Pass its parameters explicitly."
		}
	}
}
