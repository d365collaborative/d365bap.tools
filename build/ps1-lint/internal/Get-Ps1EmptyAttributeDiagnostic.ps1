function Get-Ps1EmptyAttributeDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	foreach ($parameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		foreach ($attribute in $parameter.Attributes) {
			if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
			if ($attribute.NamedArguments.Count -gt 0 -or $attribute.PositionalArguments.Count -gt 0) { continue }

			[pscustomobject]@{
				RuleName   = 'PSAvoidEmptyParameterAttribute'
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $attribute.Extent.StartLineNumber
				Column     = $attribute.Extent.StartColumnNumber
				Message    = "Remove the empty [Parameter()] attribute on -$($parameter.Name.VariablePath.UserPath). It adds no value."
			}
		}
	}
}
