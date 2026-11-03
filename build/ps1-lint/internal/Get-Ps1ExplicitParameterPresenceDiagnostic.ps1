function Get-Ps1PresenceOwnerFunction {
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

function Get-Ps1PresenceParameter {
	param($Function, [string] $Name)

	if ($null -eq $Function) { $null; return }

	foreach ($itemParameter in @($Function.Parameters) + @($Function.Body.ParamBlock.Parameters)) {
		if ($null -eq $itemParameter) { continue }
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

function Get-Ps1ExplicitParameterPresenceDiagnostic {
	param([hashtable] $Analysis)
	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemCall in @(Get-Ps1AstNode $Analysis InvokeMemberExpressionAst)) {
		if ($itemCall.Expression -isnot [Management.Automation.Language.VariableExpressionAst] -or $itemCall.Expression.VariablePath.UserPath -ine 'PSBoundParameters') { continue }
		if ($itemCall.Member -isnot [Management.Automation.Language.StringConstantExpressionAst] -or $itemCall.Member.Value -notin @('Contains', 'ContainsKey')) { continue }
		$tmpArguments = @($itemCall.Arguments)
		if ($tmpArguments.Count -ne 1) { continue }
		$literal = $tmpArguments[0] -is [Management.Automation.Language.StringConstantExpressionAst]
		$parameter = $null
		if ($literal) {
			$parameter = Get-Ps1PresenceParameter -Function (Get-Ps1PresenceOwnerFunction -Node $itemCall) `
				-Name $tmpArguments[0].Value
  }
		$aliasKey = $null -ne $parameter -and $parameter.Name.VariablePath.UserPath -ine $tmpArguments[0].Value
		if ($aliasKey) {
			$name = $parameter.Name.VariablePath.UserPath.Replace("'", "''")
			New-Ps1Diagnostic $Analysis.Path 'PSUseExplicitParameterPresenceCheck' "PSBoundParameters uses the declared name, not an alias. Use `$PSBoundParameters.ContainsKey('$name')." $itemCall.Extent
		}
		elseif ($itemCall.Member.Value -ieq 'Contains') {
			$argument = if ($null -ne $parameter) { "'" + $parameter.Name.VariablePath.UserPath.Replace("'", "''") + "'" } else { $tmpArguments[0].Extent.Text }
			New-Ps1Diagnostic $Analysis.Path 'PSUseExplicitParameterPresenceCheck' "Use `$PSBoundParameters.ContainsKey($argument) for a presence check." $itemCall.Extent
		}
	}
}
