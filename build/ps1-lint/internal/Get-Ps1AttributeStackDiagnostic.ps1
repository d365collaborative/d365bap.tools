function Write-Ps1AttributeStackDiagnostic {
	param([string] $Path, [string] $Parameter, [string] $Message, $Extent)
	[pscustomobject]@{
		RuleName   = 'PSUseStandardAttributeStack'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message -replace '\{Parameter\}', $Parameter
	}
}

function Get-Ps1AttributeStackDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/functions/[^/]+\.ps1$') { return }

	$function = @($Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($Path) })[0]
	if ($null -eq $function -or $null -eq $function.Body.ParamBlock) { return }

	foreach ($parameter in $function.Body.ParamBlock.Parameters) {
		$items = @(
			foreach ($attribute in $parameter.Attributes) {
				$rank = if ($attribute -is [Management.Automation.Language.TypeConstraintAst]) {
					2
				}
				elseif ($attribute.TypeName.GetReflectionAttributeType() -eq [Management.Automation.ParameterAttribute]) {
					0
				}
				else { 1 }
				[pscustomobject]@{ Rank = $rank; Ast = $attribute }
			}
			[pscustomobject]@{ Rank = 3; Ast = $parameter.Name }
		)

		$ordered = $true
		for ($index = 1; $index -lt $items.Count; $index++) {
			$previous = $items[$index - 1]
			$current = $items[$index]
			if ($current.Rank -lt $previous.Rank) {
				if ($ordered) {
					$ordered = $false
					Write-Ps1AttributeStackDiagnostic $Path $parameter.Name.VariablePath.UserPath "Stack [Parameter()] attributes first, then the remaining attributes, the type constraint, and the parameter name on -{Parameter}." $current.Ast.Extent
				}
			}
			if ($current.Ast.Extent.StartLineNumber - $previous.Ast.Extent.EndLineNumber -gt 1) {
				Write-Ps1AttributeStackDiagnostic $Path $parameter.Name.VariablePath.UserPath "Remove the blank line inside the attribute stack on -{Parameter}." $current.Ast.Extent
			}
		}

		$type = @($items | Where-Object { $_.Rank -eq 2 })[-1]
		if ($null -ne $type -and $parameter.Name.Extent.StartLineNumber - $type.Ast.Extent.EndLineNumber -eq 1) {
			Write-Ps1AttributeStackDiagnostic $Path $parameter.Name.VariablePath.UserPath "Keep the type constraint and parameter name on the same line for -{Parameter}." $parameter.Name.Extent
		}
	}
}
