function Write-Ps1ParameterContractDiagnostic {
	param([string] $Path, [string] $Rule, [string] $Message, $Extent)
	[pscustomobject]@{
		RuleName   = $Rule
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Test-Ps1WildcardSupport {
	param($Parameter)
	$null -ne (Get-Ps1ParameterWildcardAttribute -Parameter $Parameter)
}

function Get-Ps1ParameterWildcardAttribute {
	param($Parameter)
	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.SupportsWildcardsAttribute] -or
				$_.TypeName.FullName -in @('SupportsWildcards', 'SupportsWildcardsAttribute', 'System.Management.Automation.SupportsWildcardsAttribute')
			)
		})[0]
}

function Get-Ps1ParameterOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return $parent }
		$parent = $parent.Parent
	}
	$null
}

function Test-Ps1MandatoryParameter {
	param($Parameter)
	foreach ($itemAttribute in $Parameter.Attributes) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
		foreach ($itemArgument in $itemAttribute.NamedArguments) {
			if ($itemArgument.ArgumentName -ne 'Mandatory') { continue }
			if ($itemArgument.Argument.Extent.Text -ieq '$true') { return $true }
			if ($itemArgument.Argument -is [Management.Automation.Language.ConstantExpressionAst] -and
				$itemArgument.Argument.Value -eq $true) { return $true }
		}
	}
	$false
}

function Test-Ps1ShorthandMandatory {
	param($Argument)
	$Argument.Argument -is [Management.Automation.Language.ConstantExpressionAst] -and $Argument.Argument.Value -eq $true
}

function Test-Ps1ValidateNotNullOrEmpty {
	param($Parameter)
	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.ValidateNotNullOrEmptyAttribute] -or
				$_.TypeName.FullName -in @('ValidateNotNullOrEmpty', 'ValidateNotNullOrEmptyAttribute', 'System.Management.Automation.ValidateNotNullOrEmptyAttribute')
			)
		}).Count -gt 0
}

function Get-Ps1ParameterAttributeDefault {
	if ($null -ne $script:Ps1ParameterAttributeDefaults) { return $script:Ps1ParameterAttributeDefaults }
	$hashDefaults = @{}
	foreach ($itemProperty in [System.Management.Automation.ParameterAttribute]::new().PSObject.Properties) {
		if (-not $itemProperty.IsSettable) { continue }
		$hashDefaults[$itemProperty.Name] = $itemProperty.Value
	}
	$script:Ps1ParameterAttributeDefaults = $hashDefaults
	$hashDefaults
}

function Get-Ps1ArgumentValue {
	param($Argument)
	if ($Argument -is [Management.Automation.Language.ConstantExpressionAst]) { return $Argument.Value }
	$text = $Argument.Extent.Text
	if ($text -ieq '$true') { return $true }
	if ($text -ieq '$false') { return $false }
	if ($text -ieq '$null') { return $null }
	[System.DBNull]::Value
}

function Test-Ps1SameValue {
	param($Left, $Right)
	if ($null -eq $Left -and $null -eq $Right) { return $true }
	if ($null -eq $Left -or $null -eq $Right) { return $false }
	if ($Left.GetType() -ne $Right.GetType()) { return $false }
	$Left.Equals($Right)
}

function Get-Ps1ParameterContractDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$fileName = [IO.Path]::GetFileName($Path)
	$positionAllowed = $normalized -match '/d365bap\.tools/(functions|internal)/' -and
	$fileName -notlike '*Tests.ps1' -and
	$fileName -ne 'Get-PpacFinOpsAsset.ps1'

	$colFunctionParameters = [System.Collections.Generic.HashSet[object]]::new()
	$hashParameterFunctions = [System.Collections.Generic.Dictionary[object, object]]::new()
	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		foreach ($itemParameter in $itemFunction.Parameters) {
			$null = $colFunctionParameters.Add($itemParameter)
			if (-not $hashParameterFunctions.ContainsKey($itemParameter)) { $hashParameterFunctions[$itemParameter] = $itemFunction }
		}
		if ($null -eq $itemFunction.Body.ParamBlock) { continue }
		foreach ($itemParameter in $itemFunction.Body.ParamBlock.Parameters) {
			$null = $colFunctionParameters.Add($itemParameter)
			if (-not $hashParameterFunctions.ContainsKey($itemParameter)) { $hashParameterFunctions[$itemParameter] = $itemFunction }
		}
	}

	$defaults = Get-Ps1ParameterAttributeDefault

	foreach ($itemParameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		$name = $itemParameter.Name.VariablePath.UserPath

		foreach ($itemAttribute in $itemParameter.Attributes) {
			if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }

			if ($itemAttribute.NamedArguments.Count -eq 0 -and $itemAttribute.PositionalArguments.Count -eq 0) {
				Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidRedundantParameterAttribute' "Remove the empty [Parameter()] attribute on -$name. It adds no value." $itemAttribute.Extent
			}

			foreach ($itemArgument in $itemAttribute.NamedArguments) {
				if ($itemArgument.ArgumentName -eq 'Mandatory' -and (Test-Ps1ShorthandMandatory $itemArgument)) {
					Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidShorthandMandatory' "Use the explicit form [Parameter(Mandatory = `$true)] instead of the shorthand Mandatory on -$name." $itemArgument.Argument.Extent
				}

				if ($positionAllowed -and $itemArgument.ArgumentName -ieq 'Position') {
					Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidExplicitParameterPosition' "Remove the explicit Position = $($itemArgument.Argument.Extent.Text) argument from -$name; declaration order defines parameter positions." $itemArgument.Extent
				}

				$default = $null
				$known = $false
				foreach ($itemKey in $defaults.Keys) {
					if ($itemArgument.ArgumentName -ine $itemKey) { continue }
					$default = $defaults[$itemKey]
					$known = $true
					break
				}
				if (-not $known) { continue }

				$value = Get-Ps1ArgumentValue $itemArgument.Argument
				if (-not (Test-Ps1SameValue $value $default)) { continue }
				Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidRedundantParameterAttribute' "Remove the redundant $($itemArgument.ArgumentName) = $($itemArgument.Argument.Extent.Text) argument on -$name; it restates the [Parameter()] default." $itemArgument.Extent
			}
		}

		if ((Test-Ps1MandatoryParameter $itemParameter) -and $null -eq $itemParameter.DefaultValue) {
			$isString = @($itemParameter.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
				}).Count -gt 0
			if ($isString -and -not (Test-Ps1ValidateNotNullOrEmpty $itemParameter)) {
				Write-Ps1ParameterContractDiagnostic $Path 'PSUseValidateNotNullOrEmpty' "Parameter -$name is mandatory but does not declare [ValidateNotNullOrEmpty()]. Add the attribute to reject null or empty values." $itemParameter.Extent
			}
		}

		if ($colFunctionParameters.Contains($itemParameter) -and
			$null -ne $itemParameter.DefaultValue -and
			$itemParameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and
			$itemParameter.DefaultValue.Value.Contains('*')) {
			$isString = @($itemParameter.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
				}).Count -gt 0
			if ($isString -and -not (Test-Ps1WildcardSupport $itemParameter)) {
				Write-Ps1ParameterContractDiagnostic $Path 'PSUseSupportsWildcards' "Parameter -$name has a wildcard default value. Add [SupportsWildcards()] to the parameter." $itemParameter.DefaultValue.Extent
			}
		}

		if ($colFunctionParameters.Contains($itemParameter)) {
			$wildcardAttribute = Get-Ps1ParameterWildcardAttribute $itemParameter

			if ($null -ne $wildcardAttribute) {
				$hasStarDefault = $null -ne $itemParameter.DefaultValue -and
				$itemParameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and
				$itemParameter.DefaultValue.Value -eq '*'

				if (-not $hasStarDefault) {
					Write-Ps1ParameterContractDiagnostic $Path 'PSUseSupportsWildcards' "Parameter -$name declares [SupportsWildcards()] but does not default to '*'. Wildcard parameters always have a value; set the default to '*'." $wildcardAttribute.Extent
				}

				if ($hashParameterFunctions.ContainsKey($itemParameter)) {
					$owner = $hashParameterFunctions[$itemParameter]
					$tmpLookups = @($owner.Body.FindAll({
								param($node)
								$node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
								$node.Expression -is [Management.Automation.Language.VariableExpressionAst] -and
								$node.Expression.VariablePath.UserPath -ieq 'PSBoundParameters' -and
								$node.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
								$node.Member.Value -in @('ContainsKey', 'Contains') -and
								@($node.Arguments).Count -eq 1
							}, $true))

					foreach ($itemLookup in $tmpLookups) {
						if ((Get-Ps1ParameterOwnerFunction -Node $itemLookup) -ne $owner) { continue }

						$itemArgument = @($itemLookup.Arguments)[0]
						$itemKey = $null
						if ($itemArgument -is [Management.Automation.Language.StringConstantExpressionAst]) { $itemKey = $itemArgument.Value }
						elseif ($itemArgument -is [Management.Automation.Language.ExpandableStringExpressionAst] -and $itemArgument.NestedExpressions.Count -eq 0) { $itemKey = $itemArgument.Value }
						if ($null -eq $itemKey -or $itemKey -ine $name) { continue }

						Write-Ps1ParameterContractDiagnostic $Path 'PSUseSupportsWildcards' "Parameter -$name is a wildcard parameter and always has a value, so `$PSBoundParameters.$($itemLookup.Member.Value)('$name') is unnecessary. Use -$name directly." $itemLookup.Extent
					}
				}
			}
		}
	}
}
