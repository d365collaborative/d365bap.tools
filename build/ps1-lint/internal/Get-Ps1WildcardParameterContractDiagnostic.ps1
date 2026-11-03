function Get-Ps1WildcardAttribute {
	param($Parameter)

	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.SupportsWildcardsAttribute] -or
				$_.TypeName.FullName -in @('SupportsWildcards', 'SupportsWildcardsAttribute', 'System.Management.Automation.SupportsWildcardsAttribute')
			)
		})[0]
}

function Test-Ps1WildcardStringType {
	param($Parameter)

	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.TypeConstraintAst] -and
			$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
		}).Count -gt 0
}

function Test-Ps1WildcardDefault {
	param($Parameter)

	$null -ne $Parameter.DefaultValue -and
	$Parameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and
	$Parameter.DefaultValue.Value.Contains('*')
}

function Test-Ps1WildcardStarDefault {
	param($Parameter)

	$null -ne $Parameter.DefaultValue -and
	$Parameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and
	$Parameter.DefaultValue.Value -eq '*'
}

function Get-Ps1WildcardOwnerFunction {
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

# An unqualified name and local:Name both refer to the declared parameter.
# Any other scope qualifier is a different variable.
function Get-Ps1WildcardVariableName {
	param($Variable)

	$userPath = $Variable.VariablePath.UserPath
	if ($userPath.StartsWith('local:', [StringComparison]::OrdinalIgnoreCase)) {
		$userPath.Substring('local:'.Length)
		return
	}
	if ($userPath.Contains(':')) { return }
	$userPath
}

function Get-Ps1WildcardDeclaredParameter {
	param($Function)

	# The two declaration forms keep their parameters on different nodes:
	# function Foo ($x) and function Foo { param ($x) }.
	$Function.Parameters
	if ($null -ne $Function.Body.ParamBlock) { $Function.Body.ParamBlock.Parameters }
}

function Get-Ps1WildcardComparisonValue {
	param($Expression)
	while ($null -ne $Expression) {
		if ($Expression -is [Management.Automation.Language.ParenExpressionAst]) { $Expression = $Expression.Pipeline; continue }
		if ($Expression -is [Management.Automation.Language.PipelineAst]) {
			if ($Expression.PipelineElements.Count -ne 1 -or $Expression.Background) { return }
			$Expression = $Expression.PipelineElements[0]; continue
		}
		if ($Expression -is [Management.Automation.Language.CommandExpressionAst]) {
			if ($Expression.Redirections.Count -gt 0) { return }
			$Expression = $Expression.Expression; continue
		}
		$Expression; return
	}
}

function Get-Ps1WildcardParameterContractDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'FunctionFile')) { return }

	foreach ($itemFunction in @(Get-Ps1AstNode $Analysis FunctionDefinitionAst)) {
		$tmpWildcard = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

		foreach ($itemParameter in @(Get-Ps1WildcardDeclaredParameter $itemFunction)) {
			$name = $itemParameter.Name.VariablePath.UserPath
			$wildcardAttribute = Get-Ps1WildcardAttribute $itemParameter
			$hasWildcardDefault = Test-Ps1WildcardDefault $itemParameter

			if ($hasWildcardDefault -and
				(Test-Ps1WildcardStringType $itemParameter) -and
				$null -eq $wildcardAttribute) {
				New-Ps1Diagnostic -Path $Path 'PSUseWildcardParameterContract' "Parameter -$name has a wildcard default value. Add [SupportsWildcards()] to the parameter." $itemParameter.DefaultValue.Extent
			}

			if ($null -ne $wildcardAttribute -and -not (Test-Ps1WildcardStarDefault $itemParameter)) {
				New-Ps1Diagnostic -Path $Path 'PSUseWildcardParameterContract' "Parameter -$name declares [SupportsWildcards()] but does not default to '*'. The wildcard contract uses '*' as its declaration default; review callers before changing it." $wildcardAttribute.Extent
			}

			if ($null -ne $wildcardAttribute -or $hasWildcardDefault) {
				$tmpWildcard.Add($name) > $null
			}
		}

		if ($tmpWildcard.Count -eq 0) { continue }

		foreach ($itemBinary in $itemFunction.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.BinaryExpressionAst] }, $true)) {
			if ((Get-Ps1WildcardOwnerFunction -Node $itemBinary) -ne $itemFunction) { continue }
			if ("$($itemBinary.Operator)" -notin @('Ieq', 'Ine', 'Ceq', 'Cne')) { continue }

			$name = $null
			foreach ($itemSide in @(
					@{ Node = $itemBinary.Left; Other = $itemBinary.Right },
					@{ Node = $itemBinary.Right; Other = $itemBinary.Left }
				)) {
				$reference = Get-Ps1WildcardComparisonValue $itemSide.Node
				$literal = Get-Ps1WildcardComparisonValue $itemSide.Other
				if ($reference -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
				$candidate = Get-Ps1WildcardVariableName $reference
				if ([string]::IsNullOrEmpty($candidate)) { continue }
				if (-not $tmpWildcard.Contains($candidate)) { continue }
				if ($literal -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
				if ($literal.Value -ne '*') { continue }
				$name = $candidate
			}

			if ($null -eq $name) { continue }

			New-Ps1Diagnostic -Path $Path 'PSUseWildcardParameterContract' "Parameter -$name is a wildcard filter. Do not compare it with the literal '*'; pass the value to the filter." $itemBinary.Extent
		}
	}
}
