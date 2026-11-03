function Test-Ps1MandatoryParameter {
	param($Parameter)
	foreach ($itemAttribute in $Parameter.Attributes) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
		foreach ($itemArgument in $itemAttribute.NamedArguments) {
			if ($itemArgument.ArgumentName -ne 'Mandatory') { continue }
			if ($itemArgument.Argument.Extent.Text -ieq '$true') { $true; return }
			if ($itemArgument.Argument -is [Management.Automation.Language.ConstantExpressionAst] -and
				$itemArgument.Argument.Value -eq $true) { $true; return }
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
	if ($null -ne $script:Ps1ParameterAttributeDefaults) { $script:Ps1ParameterAttributeDefaults; return }
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
	if ($Argument -is [Management.Automation.Language.ConstantExpressionAst]) { $Argument.Value; return }
	$text = $Argument.Extent.Text
	if ($text -ieq '$true') { $true; return }
	if ($text -ieq '$false') { $false; return }
	if ($text -ieq '$null') { return }
	[System.DBNull]::Value
}

function Test-Ps1SameValue {
	param($Left, $Right)
	if ($null -eq $Left -and $null -eq $Right) { $true; return }
	if ($null -eq $Left -or $null -eq $Right) { $false; return }
	if ($Left.GetType() -ne $Right.GetType()) { $false; return }
	$Left.Equals($Right)
}

function Test-Ps1RedundantParameterPosition {
	param($Parameter)
	if ($Parameter.Parent -is [Management.Automation.Language.ParamBlockAst]) {
		$block = $Parameter.Parent
		$colParameters = @($block.Parameters)
		$scriptBlock = $block.Parent
	}
	elseif ($Parameter.Parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
		$block = $Parameter.Parent.Body.ParamBlock
		$colParameters = @($Parameter.Parent.Parameters)
		$scriptBlock = $Parameter.Parent.Body
	}
	else { $false; return }
	if ($null -ne $scriptBlock.DynamicParamBlock) { $false; return }
	foreach ($itemAttribute in $block.Attributes) {
		if ($itemAttribute.TypeName.FullName -notin @('CmdletBinding', 'CmdletBindingAttribute')) { continue }
		foreach ($itemArgument in $itemAttribute.NamedArguments) {
			if ($itemArgument.ArgumentName -ieq 'PositionalBinding' -and $itemArgument.Argument.Extent.Text -ine '$true') { $false; return }
		}
	}
	for ($index = 0; $index -lt $colParameters.Count; $index++) {
		foreach ($itemAttribute in $colParameters[$index].Attributes) {
			if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst] -or
				$itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
			foreach ($itemArgument in $itemAttribute.NamedArguments) {
				if ($itemArgument.ArgumentName -ieq 'ParameterSetName') { $false; return }
				if ($itemArgument.ArgumentName -ine 'Position') { continue }
				if ($itemArgument.Argument -isnot [Management.Automation.Language.ConstantExpressionAst] -or $itemArgument.Argument.Value -ne $index) { $false; return }
			}
		}
	}
	$true
}

function Get-Ps1ParameterContractDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$scope = $Analysis.Scope
	$positionAllowed = $scope.IsModuleSource -and
	-not $scope.IsTestsFile

	$defaults = Get-Ps1ParameterAttributeDefault

	foreach ($itemParameter in @(Get-Ps1AstNode $Analysis ParameterAst)) {
		$name = $itemParameter.Name.VariablePath.UserPath

		foreach ($itemAttribute in $itemParameter.Attributes) {
			if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }

			if ($itemAttribute.NamedArguments.Count -eq 0 -and $itemAttribute.PositionalArguments.Count -eq 0) {
				New-Ps1Diagnostic -Path $Path 'PSAvoidRedundantParameterAttribute' "Remove the empty [Parameter()] attribute on -$name. It adds no value." $itemAttribute.Extent
			}

			foreach ($itemArgument in $itemAttribute.NamedArguments) {
				if ($itemArgument.ArgumentName -eq 'Mandatory' -and (Test-Ps1ShorthandMandatory $itemArgument)) {
					New-Ps1Diagnostic -Path $Path 'PSAvoidShorthandMandatory' "Use the explicit form [Parameter(Mandatory = `$true)] instead of the shorthand Mandatory on -$name." $itemArgument.Argument.Extent
				}

				if ($positionAllowed -and $itemArgument.ArgumentName -ieq 'Position' -and
					(Test-Ps1RedundantParameterPosition $itemParameter)) {
					New-Ps1Diagnostic -Path $Path 'PSAvoidExplicitParameterPosition' "Remove the explicit Position = $($itemArgument.Argument.Extent.Text) argument from -$name; it repeats the position supplied by declaration order in this block." $itemArgument.Extent
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
				New-Ps1Diagnostic -Path $Path 'PSAvoidRedundantParameterAttribute' "Remove the redundant $($itemArgument.ArgumentName) = $($itemArgument.Argument.Extent.Text) argument on -$name; it restates the [Parameter()] default." $itemArgument.Extent
			}
		}

		if ((Test-Ps1MandatoryParameter $itemParameter) -and $null -eq $itemParameter.DefaultValue) {
			$isString = @($itemParameter.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
				}).Count -gt 0
			if ($isString -and -not (Test-Ps1ValidateNotNullOrEmpty $itemParameter)) {
				New-Ps1Diagnostic -Path $Path 'PSUseValidateNotNullOrEmpty' "Parameter -$name is mandatory but does not declare [ValidateNotNullOrEmpty()]. Add the attribute to state the non-empty contract explicitly." $itemParameter.Extent
			}
		}
	}
}
