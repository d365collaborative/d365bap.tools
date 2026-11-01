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

function Get-Ps1MandatoryDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	foreach ($parameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		foreach ($attribute in $parameter.Attributes) {
			if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
			foreach ($argument in $attribute.NamedArguments) {
				if ($argument.ArgumentName -ne 'Mandatory') { continue }
				if (-not (Test-Ps1ShorthandMandatory $argument)) { continue }
				[pscustomobject]@{
					RuleName   = 'PSAvoidShorthandMandatory'
					Severity   = 'Error'
					ScriptName = [IO.Path]::GetFileName($Path)
					Line       = $argument.Argument.Extent.StartLineNumber
					Column     = $argument.Argument.Extent.StartColumnNumber
					Message    = "Use the explicit form [Parameter(Mandatory = `$true)] instead of the shorthand Mandatory on -$($parameter.Name.VariablePath.UserPath)."
				}
			}
		}

		if (-not (Test-Ps1MandatoryParameter $parameter)) { continue }
		if ($null -ne $parameter.DefaultValue) { continue }

		$isString = @($parameter.Attributes | Where-Object {
				$_ -is [Management.Automation.Language.TypeConstraintAst] -and
				$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
			}).Count -gt 0
		if (-not $isString) { continue }

		if (Test-Ps1ValidateNotNullOrEmpty $parameter) { continue }

		[pscustomobject]@{
			RuleName   = 'PSUseValidateNotNullOrEmpty'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $parameter.Extent.StartLineNumber
			Column     = $parameter.Extent.StartColumnNumber
			Message    = "Parameter -$($parameter.Name.VariablePath.UserPath) is mandatory but does not declare [ValidateNotNullOrEmpty()]. Add the attribute to reject null or empty values."
		}
	}
}
