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
	if (-not $rules.PSAvoidCommandAliases -and -not $rules.PSAvoidParameterAliases) { return }
	$context = @{ Functions = @{}; Aliases = @{}; RuntimeAliases = $Worker.RuntimeAliases; Cache = $Worker.Cache; CommonParameters = $Worker.CommonParameters }
	foreach ($function in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		$scope = Get-Ps1AliasScope $function.Parent
		if ($function.Name -match '^(global|script):') { $scope = $ast }
		if (-not $context.Functions.ContainsKey($scope)) { $context.Functions[$scope] = @{} }
		$metadata = Get-Ps1AliasCommandMetadata $function $context.CommonParameters
		$context.Functions[$scope][$metadata.Name] = $metadata
		foreach ($alias in Get-Ps1DeclaredAlias $function.Body.ParamBlock.Attributes) {
			if (-not $alias.Name) { continue }
			if (-not $context.Aliases.ContainsKey($scope)) { $context.Aliases[$scope] = @{} }
			$context.Aliases[$scope][$alias.Name] = $metadata.Name
		}
	}
	foreach ($parameter in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		foreach ($alias in Get-Ps1DeclaredAlias $parameter.Attributes) {
			if ($rules.PSAvoidParameterAliases) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidParameterAliases' $alias.Extent "Do not declare parameter aliases. Use '$($parameter.Name.VariablePath.UserPath)'."
			}
		}
	}
	foreach ($block in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParamBlockAst] }, $true)) {
		foreach ($alias in Get-Ps1DeclaredAlias $block.Attributes) {
			if ($rules.PSAvoidCommandAliases) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidCommandAliases' $alias.Extent "Do not declare command alias '$($alias.Name)'."
			}
		}
	}
	$commands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))
	$declarations = [Collections.Generic.HashSet[Management.Automation.Language.CommandAst]]::new()
	foreach ($command in $commands) {
		$name = $command.GetCommandName()
		if (-not $name) { continue }
		$scope = Get-Ps1AliasScope $command
		$resolved = Resolve-Ps1AliasCommand $name $scope $context
		if ($resolved.Command.Name -notin @('Set-Alias', 'New-Alias', 'Set-Item', 'New-Item')) { continue }
		$isAliasCommand = $resolved.Command.Name -in @('Set-Alias', 'New-Alias')
		if ($isAliasCommand) { $null = $declarations.Add($command) }
		$binding = [Management.Automation.Language.StaticParameterBinder]::BindCommand($command)
		try {
			if ($isAliasCommand) { $aliasNames = @($binding.BoundParameters['Name'].Value.SafeGetValue()) }
			else {
				$pathParameter = if ($binding.BoundParameters.ContainsKey('LiteralPath')) { 'LiteralPath' } else { 'Path' }
				$providerPaths = @($binding.BoundParameters[$pathParameter].Value.SafeGetValue())
				$aliasNames = @(foreach ($providerPath in $providerPaths) {
						if ($providerPath -isnot [string] -or $providerPath -notmatch '^Alias:') { continue }
						$null = $declarations.Add($command)
						$providerName = $providerPath -replace '^Alias:[\\/]*', ''
						if ($providerName) { $providerName }
						elseif ($binding.BoundParameters.ContainsKey('Name')) { $binding.BoundParameters['Name'].Value.SafeGetValue() }
					})
			}
			$target = $binding.BoundParameters['Value'].Value.SafeGetValue()
			$aliasScope = $scope
			if ($binding.BoundParameters.ContainsKey('Scope') -and $binding.BoundParameters['Scope'].Value.SafeGetValue() -in @('Script', 'Global')) { $aliasScope = $ast }
			foreach ($aliasName in $aliasNames) {
				if ($aliasName -is [string] -and $target -is [string]) {
					if (-not $context.Aliases.ContainsKey($aliasScope)) { $context.Aliases[$aliasScope] = @{} }
					$context.Aliases[$aliasScope][$aliasName] = $target
				}
			}
		}
		catch { continue }
	}
	foreach ($command in $commands) {
		$name = $command.GetCommandName()
		if (-not $name) { continue }
		$resolved = Resolve-Ps1AliasCommand $name (Get-Ps1AliasScope $command) $context
		if ($rules.PSAvoidCommandAliases) {
			if ($resolved.IsAlias) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidCommandAliases' $command.CommandElements[0].Extent "Do not use command alias '$name'. Use the full command name '$($resolved.Command.Name)'."
			}
			if ($declarations.Contains($command)) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidCommandAliases' $command.Extent 'Do not declare command aliases.'
			}
		}
		if (-not $rules.PSAvoidParameterAliases -or $null -eq $resolved.Command) { continue }
		$parameters = @(
			foreach ($element in $command.CommandElements) {
				if ($element -is [Management.Automation.Language.CommandParameterAst]) {
					[pscustomobject]@{ Name = $element.ParameterName; Extent = $element.Extent }
				}
				elseif ($element -is [Management.Automation.Language.VariableExpressionAst] -and $element.Splatted) {
					Get-Ps1SplatParameter $element $command $ast
				}
			}
		)
		foreach ($parameter in $parameters) {
			$given = $parameter.Name
			if ($resolved.Command.Names.ContainsKey($given)) { continue }
			$parameterMatches = @()
			if ($resolved.Command.Aliases.ContainsKey($given)) { $parameterMatches = @($resolved.Command.Aliases[$given]) }
			else {
				$parameterMatches = @(
					$resolved.Command.Names.Keys | Where-Object { $_.StartsWith($given, [StringComparison]::OrdinalIgnoreCase) }
					$resolved.Command.Aliases.Keys | Where-Object { $_.StartsWith($given, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { $resolved.Command.Aliases[$_] }
				) | Sort-Object -Unique
			}
			if (@($parameterMatches).Count -gt 0) {
				New-Ps1AliasDiagnostic $Path 'PSAvoidParameterAliases' $parameter.Extent "Do not use parameter alias or abbreviation '-$given'. Use the full parameter name: $($parameterMatches -join ', ')."
			}
		}
	}
}
