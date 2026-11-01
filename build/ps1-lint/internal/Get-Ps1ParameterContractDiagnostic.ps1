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
	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.SupportsWildcardsAttribute] -or
				$_.TypeName.FullName -in @('SupportsWildcards', 'SupportsWildcardsAttribute', 'System.Management.Automation.SupportsWildcardsAttribute')
			)
		}).Count -gt 0
}

function Test-Ps1MandatoryParameter {
	param($Parameter)
	foreach ($attribute in $Parameter.Attributes) {
		if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
		foreach ($argument in $attribute.NamedArguments) {
			if ($argument.ArgumentName -ne 'Mandatory') { continue }
			if ($argument.Argument.Extent.Text -ieq '$true') { return $true }
			if ($argument.Argument -is [Management.Automation.Language.ConstantExpressionAst] -and
				$argument.Argument.Value -eq $true) { return $true }
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
	$defaults = @{}
	foreach ($property in [System.Management.Automation.ParameterAttribute]::new().PSObject.Properties) {
		if (-not $property.IsSettable) { continue }
		$defaults[$property.Name] = $property.Value
	}
	$script:Ps1ParameterAttributeDefaults = $defaults
	$defaults
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

	$functionParameters = [System.Collections.Generic.HashSet[object]]::new()
	foreach ($function in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		foreach ($parameter in $function.Parameters) { $null = $functionParameters.Add($parameter) }
		if ($null -eq $function.Body.ParamBlock) { continue }
		foreach ($parameter in $function.Body.ParamBlock.Parameters) { $null = $functionParameters.Add($parameter) }
	}

	$defaults = Get-Ps1ParameterAttributeDefault

	foreach ($parameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		$name = $parameter.Name.VariablePath.UserPath

		foreach ($attribute in $parameter.Attributes) {
			if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }

			if ($attribute.NamedArguments.Count -eq 0 -and $attribute.PositionalArguments.Count -eq 0) {
				Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidRedundantParameterAttribute' "Remove the empty [Parameter()] attribute on -$name. It adds no value." $attribute.Extent
			}

			foreach ($argument in $attribute.NamedArguments) {
				if ($argument.ArgumentName -eq 'Mandatory' -and (Test-Ps1ShorthandMandatory $argument)) {
					Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidShorthandMandatory' "Use the explicit form [Parameter(Mandatory = `$true)] instead of the shorthand Mandatory on -$name." $argument.Argument.Extent
				}

				if ($positionAllowed -and $argument.ArgumentName -ieq 'Position') {
					Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidExplicitParameterPosition' "Remove the explicit Position = $($argument.Argument.Extent.Text) argument from -$name; declaration order defines parameter positions." $argument.Extent
				}

				$default = $null
				$known = $false
				foreach ($key in $defaults.Keys) {
					if ($argument.ArgumentName -ine $key) { continue }
					$default = $defaults[$key]
					$known = $true
					break
				}
				if (-not $known) { continue }

				$value = Get-Ps1ArgumentValue $argument.Argument
				if (-not (Test-Ps1SameValue $value $default)) { continue }
				Write-Ps1ParameterContractDiagnostic $Path 'PSAvoidRedundantParameterAttribute' "Remove the redundant $($argument.ArgumentName) = $($argument.Argument.Extent.Text) argument on -$name; it restates the [Parameter()] default." $argument.Extent
			}
		}

		if ((Test-Ps1MandatoryParameter $parameter) -and $null -eq $parameter.DefaultValue) {
			$isString = @($parameter.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
				}).Count -gt 0
			if ($isString -and -not (Test-Ps1ValidateNotNullOrEmpty $parameter)) {
				Write-Ps1ParameterContractDiagnostic $Path 'PSUseValidateNotNullOrEmpty' "Parameter -$name is mandatory but does not declare [ValidateNotNullOrEmpty()]. Add the attribute to reject null or empty values." $parameter.Extent
			}
		}

		if ($functionParameters.Contains($parameter) -and
			$null -ne $parameter.DefaultValue -and
			$parameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and
			$parameter.DefaultValue.Value.Contains('*')) {
			$isString = @($parameter.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
				}).Count -gt 0
			if ($isString -and -not (Test-Ps1WildcardSupport $parameter)) {
				Write-Ps1ParameterContractDiagnostic $Path 'PSUseSupportsWildcards' "Parameter -$name has a wildcard default value. Add [SupportsWildcards()] to the parameter." $parameter.DefaultValue.Extent
			}
		}
	}
}
