function New-Ps1AliasDiagnostic {
	param([string] $Path, [string] $Rule, $Extent, [string] $Message)
	[pscustomobject]@{
		RuleName   = $Rule
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1AliasDiagnostic {
	param([hashtable] $Analysis, [hashtable] $Worker)
	$Path = $Analysis.Path

	$ast = $Analysis.Ast
	try { $rules = Get-Ps1AliasConfiguration $Path $Worker.Configuration }
	catch {
		New-Ps1AliasDiagnostic $Path 'PSAliasConfiguration' $ast.Extent $_.Exception.Message
		return
	}
	$moduleRoot = Get-Ps1ModuleRoot -Path $Path
	$repositoryFunctions = if ($null -ne $moduleRoot) {
		(Get-Ps1RepositoryIndex -ModuleRoot $moduleRoot -Worker $Worker).Functions
	}
	else {
		@{}
	}
	$hashContext = @{ Functions = @{}; Aliases = @{}; RuntimeAliases = $Worker.RuntimeAliases; Cache = $Worker.Cache; CommonParameters = $Worker.CommonParameters; RepositoryFunctions = $repositoryFunctions }
	foreach ($itemFunction in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		$scope = Get-Ps1AliasScope $itemFunction.Parent
		if ($itemFunction.Name -match '^(global|script):') { $scope = $ast }
		if (-not $hashContext.Functions.ContainsKey($scope)) { $hashContext.Functions[$scope] = @{} }
		$metadata = Get-Ps1AliasCommandMetadata $itemFunction $hashContext.CommonParameters
		$hashContext.Functions[$scope][$metadata.Name] = $metadata
		foreach ($itemAlias in Get-Ps1DeclaredAlias $itemFunction.Body.ParamBlock.Attributes) {
			if (-not $itemAlias.Name) { continue }
			if (-not $hashContext.Aliases.ContainsKey($scope)) { $hashContext.Aliases[$scope] = @{} }
			$hashContext.Aliases[$scope][$itemAlias.Name] = $metadata.Name
		}
	}
	foreach ($itemParameter in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		foreach ($itemAlias in Get-Ps1DeclaredAlias $itemParameter.Attributes) {
			if ($rules.PSAvoidParameterAliases -and $itemAlias.Name -notin @($rules.AllowedParameterAliases)) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidParameterAliases' $itemAlias.Extent "Do not declare parameter aliases. Use '$($itemParameter.Name.VariablePath.UserPath)'."
			}
		}
	}
	foreach ($itemBlock in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParamBlockAst] }, $true)) {
		foreach ($itemAlias in Get-Ps1DeclaredAlias $itemBlock.Attributes) {
			if ($itemAlias.Name -notin @($rules.AllowedCommandAliases)) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidCommandAliases' $itemAlias.Extent "Do not declare command alias '$($itemAlias.Name)'."
			}
		}
	}
	$colCommands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))
	$colDeclarations = [Collections.Generic.HashSet[Management.Automation.Language.CommandAst]]::new()
	$hashDeclarationNames = @{}
	$hashResolvedCommands = @{}
	foreach ($itemCommand in $colCommands) {
		$name = $itemCommand.GetCommandName()
		if (-not $name) { continue }
		$scope = Get-Ps1AliasScope $itemCommand
		$resolved = Resolve-Ps1AliasCommand $name $scope $hashContext
		$hashResolvedCommands[$itemCommand] = $resolved
		if ($resolved.Command.Name -notin @('Set-Alias', 'New-Alias', 'Set-Item', 'New-Item')) { continue }
		$isAliasCommand = $resolved.Command.Name -in @('Set-Alias', 'New-Alias')
		if ($isAliasCommand) { $null = $colDeclarations.Add($itemCommand) }
		$binding = [Management.Automation.Language.StaticParameterBinder]::BindCommand($itemCommand)
		try {
			if ($isAliasCommand) { $tmpAliasNames = @($binding.BoundParameters['Name'].Value.SafeGetValue()) }
			else {
				$pathParameter = if ($binding.BoundParameters.ContainsKey('LiteralPath')) { 'LiteralPath' } else { 'Path' }
				$tmpProviderPaths = @($binding.BoundParameters[$pathParameter].Value.SafeGetValue())
				$tmpAliasNames = @(foreach ($itemProviderPath in $tmpProviderPaths) {
						if ($itemProviderPath -isnot [string] -or $itemProviderPath -notmatch '^Alias:') { continue }
						$null = $colDeclarations.Add($itemCommand)
						$providerName = $itemProviderPath -replace '^Alias:[\\/]*', ''
						if ($providerName) { $providerName }
						elseif ($binding.BoundParameters.ContainsKey('Name')) { $binding.BoundParameters['Name'].Value.SafeGetValue() }
					})
			}
			$target = $binding.BoundParameters['Value'].Value.SafeGetValue()
			$aliasScope = $scope
			if ($binding.BoundParameters.ContainsKey('Scope') -and $binding.BoundParameters['Scope'].Value.SafeGetValue() -in @('Script', 'Global')) { $aliasScope = $ast }
			$tmpDeclaredNames = @($tmpAliasNames | Where-Object { $_ -is [string] })
			$hashDeclarationNames[$itemCommand] = @(@($hashDeclarationNames[$itemCommand]) | Where-Object { $_ -is [string] }) + $tmpDeclaredNames
			if ($binding.BoundParameters.ContainsKey('Scope') -and $binding.BoundParameters['Scope'].Value.SafeGetValue() -in @('Script', 'Global')) { $aliasScope = $ast }
			foreach ($itemAliasName in $tmpAliasNames) {
				if ($itemAliasName -is [string] -and $target -is [string]) {
					if (-not $hashContext.Aliases.ContainsKey($aliasScope)) { $hashContext.Aliases[$aliasScope] = @{} }
					$hashContext.Aliases[$aliasScope][$itemAliasName] = $target
				}
			}
		}
		catch { continue }
	}
	foreach ($itemCommand in $colCommands) {
		$name = $itemCommand.GetCommandName()
		if (-not $name) { continue }
		$resolved = if ($colDeclarations.Count -eq 0 -and $hashResolvedCommands.ContainsKey($itemCommand)) {
			$hashResolvedCommands[$itemCommand]
		}
		else {
			Resolve-Ps1AliasCommand $name (Get-Ps1AliasScope $itemCommand) $hashContext
		}
		if ($resolved.IsAlias -and $name -notin @($rules.AllowedCommandAliases)) {
			New-Ps1AliasDiagnostic $Path 'PSAvoidCommandAliases' $itemCommand.CommandElements[0].Extent "Do not use command alias '$name'. Use the full command name '$($resolved.Command.Name)'."
		}
		if ($colDeclarations.Contains($itemCommand)) {
			$tmpDeclared = @(@($hashDeclarationNames[$itemCommand]) | Where-Object { $_ -is [string] })
			if ($tmpDeclared.Count -eq 0 -or @($tmpDeclared | Where-Object { $_ -notin @($rules.AllowedCommandAliases) }).Count -gt 0) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidCommandAliases' $itemCommand.Extent 'Do not declare command aliases.'
			}
		}
		if ($null -eq $resolved.Command) { continue }
		$tmpParameters = @(
			foreach ($itemElement in $itemCommand.CommandElements) {
				if ($itemElement -is [Management.Automation.Language.CommandParameterAst]) {
					[pscustomobject]@{ Name = $itemElement.ParameterName; Extent = $itemElement.Extent }
				}
				elseif ($itemElement -is [Management.Automation.Language.VariableExpressionAst] -and $itemElement.Splatted) {
					Get-Ps1SplatParameter $itemElement $itemCommand $ast
				}
			}
		)
		foreach ($itemParameter in $tmpParameters) {
			$given = $itemParameter.Name
			if ($resolved.Command.Names.ContainsKey($given)) { continue }
			$tmpParameterMatches = @()
			if ($resolved.Command.Aliases.ContainsKey($given)) { $tmpParameterMatches = @($resolved.Command.Aliases[$given]) }
			else {
				$tmpParameterMatches = @(
					$resolved.Command.Names.Keys | Where-Object { $_.StartsWith($given, [StringComparison]::OrdinalIgnoreCase) }
					$resolved.Command.Aliases.Keys | Where-Object { $_.StartsWith($given, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $resolved.Command.Aliases[$_] }
				) | Sort-Object -Unique
			}
			if (@($tmpParameterMatches).Count -gt 0 -and $given -notin @($rules.AllowedParameterAliases)) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidParameterAliases' $itemParameter.Extent "Do not use parameter alias or abbreviation '-$given'. Use the full parameter name: $($tmpParameterMatches -join ', ')."
			}
		}
	}
}
