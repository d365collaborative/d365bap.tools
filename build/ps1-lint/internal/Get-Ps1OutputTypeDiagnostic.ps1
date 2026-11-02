function Get-Ps1OutputTypeCommandName {
	param($Command)

	$name = $Command.GetCommandName()
	if ($null -eq $name) { $null; return }
	($name -split '\\')[-1]
}

function Get-Ps1OutputTypeDeclared {
	param($Function)

	$paramBlock = $Function.Body.ParamBlock
	if ($null -eq $paramBlock) {
		[pscustomobject]@{ HasAttribute = $false; Types = @(); Attributes = @() }; return
	}

	$colAttributes = @($paramBlock.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and
			$_.TypeName.Name -match '^OutputType(Attribute)?$'
		})
	$colTypes = [System.Collections.Generic.List[string]]::new()
	foreach ($itemAttribute in $colAttributes) {
		foreach ($itemArgument in @($itemAttribute.PositionalArguments)) {
			$typeName = $null
			if ($itemArgument -is [Management.Automation.Language.StringConstantExpressionAst]) { $typeName = $itemArgument.Value }
			elseif ($itemArgument -is [Management.Automation.Language.TypeExpressionAst]) { $typeName = $itemArgument.TypeName.FullName }
			elseif ($itemArgument -is [Management.Automation.Language.TypeConstraintAst]) { $typeName = $itemArgument.TypeName.FullName }

			if (-not [string]::IsNullOrWhiteSpace($typeName)) { $colTypes.Add($typeName.Trim("'", '"')) }
		}
	}

	[pscustomobject]@{
		HasAttribute = $colAttributes.Count -gt 0
		Types        = $colTypes.ToArray()
		Attributes   = $colAttributes
	}
}

function Get-Ps1OutputTypePSFName {
	param($Function)

	$colNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

	foreach ($itemCommand in $Function.Body.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.CommandAst] -and
				(Get-Ps1OutputTypeCommandName $Node) -eq 'Select-PSFObject'
			}, $true)) {
		$tmpElements = @($itemCommand.CommandElements)
		for ($index = 0; $index -lt $tmpElements.Count; $index++) {
			$tmpElement = $tmpElements[$index]
			if ($tmpElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if ($tmpElement.ParameterName -notin @('TypeName', 'Type')) { continue }

			$tmpArgument = $null
			if ($null -ne $tmpElement.Argument) { $tmpArgument = $tmpElement.Argument }
			elseif ($index + 1 -lt $tmpElements.Count) { $tmpArgument = $tmpElements[$index + 1] }

			if ($tmpArgument -is [Management.Automation.Language.StringConstantExpressionAst]) {
				$colNames.Add($tmpArgument.Value) > $null
			}
		}
	}

	foreach ($itemHashtable in $Function.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.HashtableAst] }, $true)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($itemPair.Item1.Value -ne 'PSTypeName') { continue }

			$tmpValue = $itemPair.Item2
			if ($tmpValue -is [Management.Automation.Language.PipelineAst] -and $tmpValue.PipelineElements.Count -eq 1) { $tmpValue = $tmpValue.PipelineElements[0] }
			if ($tmpValue -is [Management.Automation.Language.CommandExpressionAst]) { $tmpValue = $tmpValue.Expression }
			if ($tmpValue -is [Management.Automation.Language.StringConstantExpressionAst]) { $colNames.Add($tmpValue.Value) > $null }
		}
	}

	$colNames
}

function Get-Ps1OutputTypeDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$scope = $Analysis.Scope
	if (-not (Test-Ps1RuleScope $Analysis 'OutputTypeFile')) { return }

	$itemFunction = @(Get-Ps1AstNode $Analysis FunctionDefinitionAst | Where-Object { $_.Name -eq $scope.FileNameWithoutExtension })[0]
	if ($null -eq $itemFunction) { return }

	$declaration = Get-Ps1OutputTypeDeclared -Function $itemFunction
	$colPSFNames = @(Get-Ps1OutputTypePSFName -Function $itemFunction)
	$colTypes = @($declaration.Types)

	if (-not $declaration.HasAttribute) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "Function $($itemFunction.Name) must declare [OutputType()]. Use [OutputType([void])] when it emits no output." $itemFunction.Name.Extent
		return
	}

	if ($colTypes.Count -eq 0) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "OutputType on $($itemFunction.Name) must declare at least one type. Use [OutputType([void])] when it emits no output." $declaration.Attributes[0].Extent
		return
	}

	$hasVoid = @($colTypes | Where-Object { $_ -match '^(system\.)?void$' }).Count -gt 0
	if ($hasVoid -and $colTypes.Count -gt 1) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "OutputType on $($itemFunction.Name) mixes [void] with other types. Declare either [void] or the emitted types." $declaration.Attributes[0].Extent
		return
	}

	if ($colPSFNames.Count -gt 0) {
		foreach ($itemPSFName in $colPSFNames) {
			$matching = @($colTypes | Where-Object {
					$_ -ieq $itemPSFName -or $_ -ieq "$itemPSFName[]"
				}).Count -gt 0

			if (-not $matching) {
				New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "Function $($itemFunction.Name) emits '$itemPSFName' but OutputType does not declare '$itemPSFName' or '$itemPSFName[]'." $itemFunction.Name.Extent
			}
		}

		return
	}

	$hasSpecificType = @($colTypes | Where-Object { $_ -notmatch '^(system\.)?(object|psobject)(\[\])?$' }).Count -gt 0
	if (-not $hasSpecificType) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "OutputType on $($itemFunction.Name) only declares System.Object. Use the actual type, [PSCustomObject] for anonymous objects, or [void] when it emits no output." $declaration.Attributes[0].Extent
	}
}
