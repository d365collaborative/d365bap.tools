function Get-Ps1AliasScope {
	param([Management.Automation.Language.Ast] $Node)
	for ($current = $Node; $null -ne $current; $current = $current.Parent) {
		if ($current -is [Management.Automation.Language.ScriptBlockAst]) { return $current }
	}
}

function Get-Ps1SplatParameter {
	param($Splat, $Command, $Ast)

	$assignments = @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] }, $true))
	for ($scope = Get-Ps1AliasScope $Command; $null -ne $scope; $scope = Get-Ps1AliasScope $scope.Parent) {
		$definitions = @($assignments | Where-Object {
				$_.Left -is [Management.Automation.Language.VariableExpressionAst] -and
				$_.Left.VariablePath.UserPath -eq $Splat.VariablePath.UserPath -and
				$_.Extent.StartOffset -lt $Command.Extent.StartOffset -and
				(Get-Ps1AliasScope $_) -eq $scope
			} | Sort-Object { $_.Extent.StartOffset } -Descending)
		if ($definitions.Count -eq 0) { continue }
		$table = $definitions[0].Right.Find({ param($node) $node -is [Management.Automation.Language.HashtableAst] }, $true)
		if ($null -eq $table -or $table.Extent.Text -ne $definitions[0].Right.Extent.Text) { return }
		foreach ($pair in $table.KeyValuePairs) {
			if ($pair.Item1 -is [Management.Automation.Language.StringConstantExpressionAst]) {
				[pscustomobject]@{ Name = $pair.Item1.Value; Extent = $pair.Item1.Extent }
			}
		}
		foreach ($assignment in $assignments) {
			if ($assignment.Extent.StartOffset -lt $definitions[0].Extent.EndOffset -or
				$assignment.Extent.StartOffset -ge $Command.Extent.StartOffset -or (Get-Ps1AliasScope $assignment) -ne $scope) { continue }
			$left = $assignment.Left
			$key = if ($left -is [Management.Automation.Language.IndexExpressionAst] -and
				$left.Target -is [Management.Automation.Language.VariableExpressionAst] -and $left.Target.VariablePath.UserPath -eq $Splat.VariablePath.UserPath) { $left.Index }
			elseif ($left -is [Management.Automation.Language.MemberExpressionAst] -and
				$left.Expression -is [Management.Automation.Language.VariableExpressionAst] -and $left.Expression.VariablePath.UserPath -eq $Splat.VariablePath.UserPath) { $left.Member }
			else { $null }
			if ($key -is [Management.Automation.Language.StringConstantExpressionAst]) {
				[pscustomobject]@{ Name = $key.Value; Extent = $key.Extent }
			}
		}
		return
	}
}

function Get-Ps1DeclaredAlias {
	param([object[]] $Attributes)
	foreach ($attribute in $Attributes) {
		if ($attribute -isnot [Management.Automation.Language.AttributeAst] -or
			$attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.AliasAttribute]) { continue }
		$found = $false
		foreach ($argument in $attribute.PositionalArguments) {
			foreach ($literal in $argument.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
				$found = $true
				[pscustomobject]@{ Name = $literal.Value; Extent = $attribute.Extent }
			}
		}
		if (-not $found) { [pscustomobject]@{ Name = $null; Extent = $attribute.Extent } }
	}
}

function Get-Ps1AliasCommandMetadata {
	param($Command, [hashtable] $CommonParameters)
	$names = @{}
	$aliases = @{}
	if ($Command -is [Management.Automation.Language.FunctionDefinitionAst]) {
		$advanced = @($Command.Body.ParamBlock.Attributes | Where-Object {
				$_ -is [Management.Automation.Language.AttributeAst] -and
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.CmdletBindingAttribute]
			}).Count -gt 0
		if ($advanced) {
			foreach ($parameter in $CommonParameters.Values) {
				$names[$parameter.Name] = $parameter.Name
				foreach ($alias in $parameter.Aliases) { $aliases[$alias] = $parameter.Name }
			}
		}
		foreach ($parameter in @($Command.Parameters) + @($Command.Body.ParamBlock.Parameters)) {
			if ($null -eq $parameter) { continue }
			$name = $parameter.Name.VariablePath.UserPath
			$names[$name] = $name
			foreach ($alias in Get-Ps1DeclaredAlias $parameter.Attributes) {
				if ($alias.Name) { $aliases[$alias.Name] = $name }
			}
		}
	}
	elseif ($Command.CommandType -in @('Cmdlet', 'Function', 'Filter', 'ExternalScript')) {
		foreach ($parameter in $Command.Parameters.Values) {
			$names[$parameter.Name] = $parameter.Name
			foreach ($alias in $parameter.Aliases) { $aliases[$alias] = $parameter.Name }
		}
	}
	[pscustomobject]@{ Name = $Command.Name -replace '^(global|script|local|private):', ''; Names = $names; Aliases = $aliases }
}

function Resolve-Ps1AliasCommand {
	param([string] $Name, $Scope, [hashtable] $Context)
	$currentName = $Name
	$usedAlias = $false
	$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	while ($currentName -and $seen.Add($currentName)) {
		$target = $null
		$found = $false
		for ($current = $Scope; $null -ne $current; $current = Get-Ps1AliasScope $current.Parent) {
			if ($Context.Aliases.ContainsKey($current) -and $Context.Aliases[$current].ContainsKey($currentName)) {
				$target = $Context.Aliases[$current][$currentName]
				$found = $true
				break
			}
		}
		if (-not $found -and $Context.RuntimeAliases.ContainsKey($currentName)) {
			$target = $Context.RuntimeAliases[$currentName]
			$found = $true
		}
		if ($found) {
			$usedAlias = $true
			$currentName = $target
			continue
		}
		for ($current = $Scope; $null -ne $current; $current = Get-Ps1AliasScope $current.Parent) {
			if ($Context.Functions.ContainsKey($current) -and $Context.Functions[$current].ContainsKey($currentName)) {
				return [pscustomobject]@{ IsAlias = $usedAlias; Command = $Context.Functions[$current][$currentName] }
			}
		}
		if (-not $Context.Cache.ContainsKey($currentName)) {
			$command = Get-Command -Name ([Management.Automation.WildcardPattern]::Escape($currentName)) -ErrorAction SilentlyContinue
			$Context.Cache[$currentName] = if ($null -ne $command -and $command.CommandType -eq 'Alias') {
				@{ Target = $command.Definition; Metadata = $null }
			}
			else {
				@{ Target = $null; Metadata = $(if ($null -ne $command) { Get-Ps1AliasCommandMetadata $command $Context.CommonParameters } else { $null }) }
			}
		}
		$cached = $Context.Cache[$currentName]
		if ($cached.Target) {
			$usedAlias = $true
			$currentName = $cached.Target
			continue
		}
		return [pscustomobject]@{ IsAlias = $usedAlias; Command = $cached.Metadata }
	}
	[pscustomobject]@{ IsAlias = $usedAlias; Command = $null }
}
