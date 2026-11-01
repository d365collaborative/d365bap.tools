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

function Get-Ps1ParameterArgumentDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path
	$defaults = Get-Ps1ParameterAttributeDefault

	foreach ($parameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		foreach ($attribute in $parameter.Attributes) {
			if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
			foreach ($argument in $attribute.NamedArguments) {
				$default = $null
				$known = $false
				foreach ($name in $defaults.Keys) {
					if ($argument.ArgumentName -ine $name) { continue }
					$default = $defaults[$name]
					$known = $true
					break
				}
				if (-not $known) { continue }

				$value = Get-Ps1ArgumentValue $argument.Argument
				if (-not (Test-Ps1SameValue $value $default)) { continue }

				[pscustomobject]@{
					RuleName   = 'PSAvoidRedundantParameterArgument'
					Severity   = 'Error'
					ScriptName = [IO.Path]::GetFileName($Path)
					Line       = $argument.Extent.StartLineNumber
					Column     = $argument.Extent.StartColumnNumber
					Message    = "Remove the redundant $($argument.ArgumentName) = $($argument.Argument.Extent.Text) argument on -$($parameter.Name.VariablePath.UserPath); it restates the [Parameter()] default."
				}
			}
		}
	}
}
