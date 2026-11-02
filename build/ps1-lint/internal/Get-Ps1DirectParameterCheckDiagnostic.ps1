function Get-Ps1DirectOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
			$parent
			return
		}
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1DirectParameter {
	param($Function, [string] $Name)

	if ($null -eq $Function -or $null -eq $Function.Body.ParamBlock) { $null; return }

	foreach ($itemParameter in $Function.Body.ParamBlock.Parameters) {
		if ($itemParameter.Name.VariablePath.UserPath -ieq $Name) { $itemParameter; return }

		foreach ($itemAttribute in $itemParameter.Attributes) {
			if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [System.Management.Automation.AliasAttribute]) { continue }
			foreach ($itemArgument in $itemAttribute.PositionalArguments) {
				if ($itemArgument -is [Management.Automation.Language.StringConstantExpressionAst] -and $itemArgument.Value -ieq $Name) {
					$itemParameter
					return
				}
			}
		}
	}
	$null
}

function Test-Ps1DirectMandatory {
	param($Parameter)

	foreach ($itemAttribute in $Parameter.Attributes) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [System.Management.Automation.ParameterAttribute]) { continue }
		foreach ($itemArgument in $itemAttribute.NamedArguments) {
			if ($itemArgument.ArgumentName -ine 'Mandatory') { continue }
			if ($itemArgument.Argument.Extent.Text -ieq '$true') { $true; return }
		}
	}
	$false
}

function Test-Ps1DirectDefaultAllowed {
	param($Parameter)

	$default = $Parameter.DefaultValue
	if ($null -eq $default) { $false; return }

	if ($default -is [Management.Automation.Language.StringConstantExpressionAst]) {
		if ($default.Value.Contains('*')) { $true; return }
		if (-not [string]::IsNullOrEmpty($default.Value)) { $true; return }
		$false
		return
	}

	$default -is [Management.Automation.Language.ConstantExpressionAst] -and -not ($null -eq $default.Value)
}

function Get-Ps1DirectSetMap {
	param($Function)

	$hashSets = @{}
	$defaultSet = $null
	if ($null -eq $Function.Body.ParamBlock) {
		@{
			Sets    = $hashSets
			Default = $null
		}
		return
	}

	foreach ($itemAttribute in $Function.Body.ParamBlock.Attributes) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [System.Management.Automation.CmdletBindingAttribute]) { continue }
		foreach ($itemArgument in $itemAttribute.NamedArguments) {
			if ($itemArgument.ArgumentName -ine 'DefaultParameterSetName') { continue }
			if ($itemArgument.Argument -is [Management.Automation.Language.StringConstantExpressionAst]) {
				$defaultSet = $itemArgument.Argument.Value
			}
		}
	}

	foreach ($itemParameter in $Function.Body.ParamBlock.Parameters) {
		foreach ($itemAttribute in $itemParameter.Attributes) {
			if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [System.Management.Automation.ParameterAttribute]) { continue }
			foreach ($itemArgument in $itemAttribute.NamedArguments) {
				if ($itemArgument.ArgumentName -ine 'ParameterSetName') { continue }
				if ($itemArgument.Argument -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
				$setName = $itemArgument.Argument.Value
				if (-not $hashSets.ContainsKey($setName)) { $hashSets[$setName] = [System.Collections.Generic.List[string]]::new() }
				$hashSets[$setName].Add($itemParameter.Name.VariablePath.UserPath)
			}
		}
	}

	@{ Sets = $hashSets; Default = $defaultSet }
}

function Get-Ps1DirectSetParameter {
	param($Function, [string] $SetName)

	$map = Get-Ps1DirectSetMap -Function $Function
	if (-not $map.Sets.ContainsKey($SetName)) { $null; return }

	$colNames = @($map.Sets[$SetName])
	foreach ($itemName in $colNames) {
		$parameter = Get-Ps1DirectParameter -Function $Function `
			-Name $itemName
		if ($null -eq $parameter) { continue }
		if (Test-Ps1DirectMandatory -Parameter $parameter) { $itemName; return }
	}
	if ($colNames.Count -gt 0) { $colNames[0]; return }
	$null
}

function Test-Ps1DirectValueTest {
	param($Node, [string] $Name)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.IfStatementAst]) {
			$condition = $parent.Clauses[0].Item1
			@($condition.FindAll({
						param($itemNode)
						$itemNode -is [Management.Automation.Language.VariableExpressionAst] -and
						$itemNode.VariablePath.UserPath -ieq $Name
					}, $true)).Count -gt 0
			return
		}
		if ($parent -is [Management.Automation.Language.AssignmentStatementAst]) {
			@($parent.Right.FindAll({
						param($itemNode)
						$itemNode -is [Management.Automation.Language.VariableExpressionAst] -and
						$itemNode.VariablePath.UserPath -ieq $Name
					}, $true)).Count -gt 0
			return
		}
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { break }
		$parent = $parent.Parent
	}
	$false
}

function Get-Ps1DirectParameterCheckDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemMember in @(Get-Ps1AstNode $Analysis MemberExpressionAst)) {
		if ($itemMember.Expression -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
		if ($itemMember.Expression.VariablePath.UserPath -ine 'PSCmdlet') { continue }
		if ($itemMember.Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($itemMember.Member.Value -ine 'ParameterSetName') { continue }

		$function = Get-Ps1DirectOwnerFunction -Node $itemMember
		if ($null -eq $function) { continue }

		$switchNode = $itemMember.Parent
		while ($null -ne $switchNode -and $switchNode -isnot [Management.Automation.Language.SwitchStatementAst] -and $switchNode -isnot [Management.Automation.Language.FunctionDefinitionAst]) {
			$switchNode = $switchNode.Parent
		}
		if ($switchNode -is [Management.Automation.Language.SwitchStatementAst]) {
			$map = Get-Ps1DirectSetMap -Function $function
			$tmpNonDefault = @($map.Sets.Keys | Where-Object { $_ -ne $map.Default })
			$parameterName = $null
			if ($tmpNonDefault.Count -gt 0) {
				$parameterName = Get-Ps1DirectSetParameter -Function $function `
					-SetName $tmpNonDefault[0]
			}
			if ($null -eq $parameterName) {
				New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' 'Do not switch on $PSCmdlet.ParameterSetName. Test the parameter directly instead.' $itemMember.Extent
				continue
			}
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Do not switch on `$PSCmdlet.ParameterSetName. Test the parameter directly: if (-not `$$parameterName) { ... }." $itemMember.Extent
			continue
		}

		$binary = $itemMember.Parent
		while ($null -ne $binary -and $binary -isnot [Management.Automation.Language.BinaryExpressionAst] -and $binary -isnot [Management.Automation.Language.FunctionDefinitionAst]) {
			$binary = $binary.Parent
		}

		$setName = $null
		if ($binary -is [Management.Automation.Language.BinaryExpressionAst] -and "$($binary.Operator)" -in @('Ieq', 'Ceq')) {
			foreach ($itemSide in @($binary.Left, $binary.Right)) {
				if ($itemSide -is [Management.Automation.Language.StringConstantExpressionAst]) { $setName = $itemSide.Value }
			}
		}

		$parameterName = $null
		if ($null -ne $setName) {
			$parameterName = Get-Ps1DirectSetParameter -Function $function `
				-SetName $setName
		}

		if ($null -eq $parameterName) {
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' 'Do not test $PSCmdlet.ParameterSetName. Test the parameter directly instead.' $itemMember.Extent
			continue
		}

		$assignment = $itemMember.Parent
		while ($null -ne $assignment -and $assignment -isnot [Management.Automation.Language.AssignmentStatementAst] -and $assignment -isnot [Management.Automation.Language.FunctionDefinitionAst]) {
			$assignment = $assignment.Parent
		}
		if ($assignment -is [Management.Automation.Language.AssignmentStatementAst] -and $assignment.Left -is [Management.Automation.Language.VariableExpressionAst]) {
			$variableName = $assignment.Left.VariablePath.UserPath
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Do not store `$PSCmdlet.ParameterSetName. Test the parameter directly: `$$variableName = [bool] `$$parameterName." $itemMember.Extent
			continue
		}

		New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Do not test `$PSCmdlet.ParameterSetName. The set is selected by -$parameterName; test the parameter directly: if (`$$parameterName) { ... } else { ... }." $itemMember.Extent
	}

	foreach ($itemInvoke in @(Get-Ps1AstNode $Analysis InvokeMemberExpressionAst)) {
		if ($itemInvoke.Expression -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
		if ($itemInvoke.Expression.VariablePath.UserPath -ine 'PSBoundParameters') { continue }
		if ($itemInvoke.Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($itemInvoke.Member.Value -notin @('ContainsKey', 'Contains')) { continue }

		$tmpArguments = @($itemInvoke.Arguments)
		if ($tmpArguments.Count -ne 1) { continue }
		if ($tmpArguments[0] -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }

		$key = $tmpArguments[0].Value
		$function = Get-Ps1DirectOwnerFunction -Node $itemInvoke
		if ($null -eq $function) { continue }

		$parameter = Get-Ps1DirectParameter -Function $function `
			-Name $key
		if ($null -eq $parameter) { continue }
		if (Test-Ps1DirectDefaultAllowed -Parameter $parameter) { continue }

		$parameterName = $parameter.Name.VariablePath.UserPath

		if (Test-Ps1DirectMandatory -Parameter $parameter) {
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Parameter -$parameterName is mandatory and always bound. Remove the `$PSBoundParameters.$($itemInvoke.Member.Value)('$key') check." $itemInvoke.Extent
			continue
		}

		if (Test-Ps1DirectValueTest -Node $itemInvoke `
				-Name $parameterName) {
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Remove the redundant `$PSBoundParameters.$($itemInvoke.Member.Value)('$key') check; the value test for `$$parameterName already decides." $itemInvoke.Extent
			continue
		}

		if ($parameterName -match '(?i)Version$') {
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Do not gate the default on `$PSBoundParameters.$($itemInvoke.Member.Value)('$key'). Use if ([string]::IsNullOrWhiteSpace(`$$parameterName)) { <default> } else { `$$parameterName }, or give -$parameterName a default value." $itemInvoke.Extent
			continue
		}

		if ($parameter.StaticType -eq [string]) {
			New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Do not gate on `$PSBoundParameters.$($itemInvoke.Member.Value)('$key'). An omitted string parameter is empty; test the value directly with [string]::IsNullOrEmpty(`$$parameterName) or if (`$$parameterName). Do not add a default value." $itemInvoke.Extent
			continue
		}

		New-Ps1Diagnostic $Path 'PSUseDirectParameterCheck' "Do not gate on `$PSBoundParameters.$($itemInvoke.Member.Value)('$key'). Trust the parameter's null value and test -not (`$null -eq `$$parameterName) directly. Do not add a default value." $itemInvoke.Extent
	}
}
