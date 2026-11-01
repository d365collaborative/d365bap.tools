function Test-Ps1WildcardSupport {
	param($Parameter)
	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.SupportsWildcardsAttribute] -or
				$_.TypeName.FullName -in @('SupportsWildcards', 'SupportsWildcardsAttribute', 'System.Management.Automation.SupportsWildcardsAttribute')
			)
		}).Count -gt 0
}

function Get-Ps1WildcardDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	foreach ($function in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		$parameters = @(
			$function.Parameters
			if ($null -ne $function.Body.ParamBlock) { $function.Body.ParamBlock.Parameters }
		)
		foreach ($parameter in $parameters) {
			if ($null -eq $parameter -or $null -eq $parameter.DefaultValue) { continue }
			if ($parameter.DefaultValue -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if (-not $parameter.DefaultValue.Value.Contains('*')) { continue }

			$isString = @($parameter.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('string', 'System.String', 'string[]', 'System.String[]')
				}).Count -gt 0
			if (-not $isString) { continue }

			if (Test-Ps1WildcardSupport $parameter) { continue }

			[pscustomobject]@{
				RuleName   = 'PSUseSupportsWildcards'
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $parameter.DefaultValue.Extent.StartLineNumber
				Column     = $parameter.DefaultValue.Extent.StartColumnNumber
				Message    = "Parameter -$($parameter.Name.VariablePath.UserPath) has a wildcard default value. Add [SupportsWildcards()] to the parameter."
			}
		}
	}
}
