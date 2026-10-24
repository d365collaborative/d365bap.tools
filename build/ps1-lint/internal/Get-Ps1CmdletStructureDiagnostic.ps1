function Get-Ps1CmdletStructureDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$ast = $Analysis.Ast
	$nonFunctions = @($ast.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] })
	$isFunctionFile = $null -eq $ast.ParamBlock -and $ast.EndBlock.Statements.Count -gt 0 -and
	$nonFunctions.Count -eq 0 -and $ast.EndBlock.Traps.Count -eq 0 -and
	$null -eq $ast.BeginBlock -and $null -eq $ast.ProcessBlock -and
	$null -eq $ast.DynamicParamBlock -and $null -eq $ast.CleanBlock
	if ($isFunctionFile) { return }

	foreach ($attribute in $ast.ParamBlock.Attributes) {
		if ($attribute.TypeName.GetReflectionAttributeType() -eq [Management.Automation.CmdletBindingAttribute]) { return }
	}

	[pscustomobject]@{
		RuleName   = 'PSUseCmdletStructure'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = 1
		Column     = 1
		Message    = 'Scripts must declare [CmdletBinding()] and a script-level param(...) block, even when empty. Only function-only files are exempt.'
	}
}
