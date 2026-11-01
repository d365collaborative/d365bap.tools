function Get-Ps1ParameterPositionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ([IO.Path]::GetFileName($Path) -eq 'Get-PpacFinOpsAsset.ps1') { return }

	foreach ($parameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		foreach ($attribute in $parameter.Attributes) {
			if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
			if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.ParameterAttribute]) { continue }
			foreach ($argument in $attribute.NamedArguments) {
				if ($argument.ArgumentName -ine 'Position') { continue }

				[pscustomobject]@{
					RuleName   = 'PSAvoidExplicitParameterPosition'
					Severity   = 'Error'
					ScriptName = [IO.Path]::GetFileName($Path)
					Line       = $argument.Extent.StartLineNumber
					Column     = $argument.Extent.StartColumnNumber
					Message    = "Remove the explicit Position = $($argument.Argument.Extent.Text) argument from -$($parameter.Name.VariablePath.UserPath); declaration order defines parameter positions."
				}
			}
		}
	}
}
