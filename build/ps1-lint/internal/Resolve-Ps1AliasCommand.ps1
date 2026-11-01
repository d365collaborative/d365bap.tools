function Get-Ps1AliasScope {
	param([Management.Automation.Language.Ast] $Node)
	for ($current = $Node; $null -ne $current; $current = $current.Parent) {
		if ($current -is [Management.Automation.Language.ScriptBlockAst]) { $current; return }
	}
}

function Get-Ps1AliasScopeChain {
	param($Scope)

	for ($current = $Scope; $null -ne $current; $current = $current.Parent) {
		if ($current -is [Management.Automation.Language.ScriptBlockAst]) { $current }
	}
}

function Get-Ps1SplatParameter {
	param($Splat, $Command, $Ast)

	$colAssignments = @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] }, $true))
	for ($scope = Get-Ps1AliasScope $Command; $null -ne $scope; $scope = Get-Ps1AliasScope $scope.Parent) {
		$tmpDefinitions = @($colAssignments | Where-Object {
				$_.Left -is [Management.Automation.Language.VariableExpressionAst] -and
				$_.Left.VariablePath.UserPath -eq $Splat.VariablePath.UserPath -and
				$_.Extent.StartOffset -lt $Command.Extent.StartOffset -and
				(Get-Ps1AliasScope $_) -eq $scope
			} | Sort-Object { $_.Extent.StartOffset } -Descending)
		if ($tmpDefinitions.Count -eq 0) { continue }
		$table = $tmpDefinitions[0].Right.Find({ param($node) $node -is [Management.Automation.Language.HashtableAst] }, $true)
		if ($null -eq $table -or $table.Extent.Text -ne $tmpDefinitions[0].Right.Extent.Text) { return }
		foreach ($itemPair in $table.KeyValuePairs) {
			if ($itemPair.Item1 -is [Management.Automation.Language.StringConstantExpressionAst]) {
				[pscustomobject]@{ Name = $itemPair.Item1.Value; Extent = $itemPair.Item1.Extent }
			}
		}
		foreach ($itemAssignment in $colAssignments) {
			if ($itemAssignment.Extent.StartOffset -lt $tmpDefinitions[0].Extent.EndOffset -or
				$itemAssignment.Extent.StartOffset -ge $Command.Extent.StartOffset -or (Get-Ps1AliasScope $itemAssignment) -ne $scope) { continue }
			$left = $itemAssignment.Left
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
	foreach ($itemAttribute in $Attributes) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst] -or
			$itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.AliasAttribute]) { continue }
		$found = $false
		foreach ($itemArgument in $itemAttribute.PositionalArguments) {
			foreach ($itemLiteral in $itemArgument.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
				$found = $true
				[pscustomobject]@{ Name = $itemLiteral.Value; Extent = $itemAttribute.Extent }
			}
		}
		if (-not $found) { [pscustomobject]@{ Name = $null; Extent = $itemAttribute.Extent } }
	}
}

function Get-Ps1AliasCommandMetadata {
	param($Command, [hashtable] $CommonParameters)
	$hashNames = @{}
	$hashAliases = @{}
	if ($Command -is [Management.Automation.Language.FunctionDefinitionAst]) {
		$advanced = @($Command.Body.ParamBlock.Attributes | Where-Object {
				$_ -is [Management.Automation.Language.AttributeAst] -and
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.CmdletBindingAttribute]
			}).Count -gt 0
		if ($advanced) {
			foreach ($itemParameter in $CommonParameters.Values) {
				$hashNames[$itemParameter.Name] = $itemParameter.Name
				foreach ($itemAlias in $itemParameter.Aliases) { $hashAliases[$itemAlias] = $itemParameter.Name }
			}
		}
		foreach ($itemParameter in @($Command.Parameters) + @($Command.Body.ParamBlock.Parameters)) {
			if ($null -eq $itemParameter) { continue }
			$name = $itemParameter.Name.VariablePath.UserPath
			$hashNames[$name] = $name
			foreach ($itemAlias in Get-Ps1DeclaredAlias $itemParameter.Attributes) {
				if ($itemAlias.Name) { $hashAliases[$itemAlias.Name] = $name }
			}
		}
	}
	elseif ($Command.CommandType -in @('Cmdlet', 'Function', 'Filter', 'ExternalScript')) {
		foreach ($itemParameter in $Command.Parameters.Values) {
			$hashNames[$itemParameter.Name] = $itemParameter.Name
			foreach ($itemAlias in $itemParameter.Aliases) { $hashAliases[$itemAlias] = $itemParameter.Name }
		}
	}
	[pscustomobject]@{ Name = $Command.Name -replace '^(global|script|local|private):', ''; Names = $hashNames; Aliases = $hashAliases }
}

function Resolve-Ps1AliasCommand {
	param([string] $Name, $Scope, [hashtable] $Context)
	$currentName = $Name
	$usedAlias = $false
	$colSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	$colScopes = @(Get-Ps1AliasScopeChain -Scope $Scope)
	while ($currentName -and $colSeen.Add($currentName)) {
		$target = $null
		$found = $false
		foreach ($itemCurrent in $colScopes) {
			if ($Context.Aliases.ContainsKey($itemCurrent) -and $Context.Aliases[$itemCurrent].ContainsKey($currentName)) {
				$target = $Context.Aliases[$itemCurrent][$currentName]
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
		foreach ($itemCurrent in $colScopes) {
			if ($Context.Functions.ContainsKey($itemCurrent) -and $Context.Functions[$itemCurrent].ContainsKey($currentName)) {
				[pscustomobject]@{ IsAlias = $usedAlias; Command = $Context.Functions[$itemCurrent][$currentName] }
				return
			}
		}
		if ($Context.ContainsKey('RepositoryFunctions') -and
			$null -ne $Context.RepositoryFunctions -and
			$Context.RepositoryFunctions.ContainsKey($currentName)) {
			[pscustomobject]@{ IsAlias = $usedAlias; Command = $Context.RepositoryFunctions[$currentName] }
			return
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
		[pscustomobject]@{ IsAlias = $usedAlias; Command = $cached.Metadata }
		return
	}
	[pscustomobject]@{ IsAlias = $usedAlias; Command = $null }
}
