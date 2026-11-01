function Write-Ps1ParameterLayoutDiagnostic {
	param([string] $Path, [string] $Message, $Extent)
	[pscustomobject]@{
		RuleName   = 'PSUseStandardParameterLayout'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ParameterLayoutDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/functions/[^/]+\.ps1$') { return }

	$function = @($Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($Path) })[0]
	if ($null -eq $function -or $null -eq $function.Body.ParamBlock) { return }

	$parameters = @($function.Body.ParamBlock.Parameters)
	for ($index = 0; $index -lt $parameters.Count; $index++) {
		$parameter = $parameters[$index]
		$name = $parameter.Name.VariablePath.UserPath

		if ($index -gt 0) {
			$previous = $parameters[$index - 1]
			if ($parameter.Extent.StartLineNumber - $previous.Extent.EndLineNumber -le 1) {
				Write-Ps1ParameterLayoutDiagnostic $Path "Add a blank line before the -$name parameter and its attributes." $parameter.Extent
			}
		}

		$items = @(
			foreach ($attribute in $parameter.Attributes) {
				$rank = if ($attribute -is [Management.Automation.Language.TypeConstraintAst]) {
					3
				}
				elseif ($attribute.TypeName.GetReflectionAttributeType() -eq [Management.Automation.ParameterAttribute]) {
					0
				}
				elseif ($attribute.TypeName.GetReflectionAttributeType() -eq [Management.Automation.ValidateSetAttribute]) {
					1
				}
				else { 2 }
				[pscustomobject]@{ Rank = $rank; Ast = $attribute }
			}
			[pscustomobject]@{ Rank = 4; Ast = $parameter.Name }
		)

		$ordered = $true
		for ($itemIndex = 1; $itemIndex -lt $items.Count; $itemIndex++) {
			$previousItem = $items[$itemIndex - 1]
			$currentItem = $items[$itemIndex]
			if ($currentItem.Rank -lt $previousItem.Rank) {
				if ($ordered) {
					$ordered = $false
					Write-Ps1ParameterLayoutDiagnostic $Path "Stack [Parameter()] attributes first, then [ValidateSet()], then the remaining attributes, the type constraint, and the parameter name on -$name." $currentItem.Ast.Extent
				}
			}
			if ($currentItem.Ast.Extent.StartLineNumber - $previousItem.Ast.Extent.EndLineNumber -gt 1) {
				Write-Ps1ParameterLayoutDiagnostic $Path "Remove the blank line inside the attribute stack on -$name." $currentItem.Ast.Extent
			}
		}

		$type = @($items | Where-Object { $_.Rank -eq 3 })[-1]
		if ($null -ne $type -and $parameter.Name.Extent.StartLineNumber - $type.Ast.Extent.EndLineNumber -eq 1) {
			Write-Ps1ParameterLayoutDiagnostic $Path "Keep the type constraint and parameter name on the same line for -$name." $parameter.Name.Extent
		}
	}

	foreach ($parameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		$attributes = @($parameter.Attributes)
		if ($attributes.Count -eq 0) { continue }
		$last = $attributes[-1]
		if ($parameter.Name.Extent.StartLineNumber -ne $last.Extent.EndLineNumber) { continue }
		$gap = $parameter.Name.Extent.StartColumnNumber - $last.Extent.EndColumnNumber
		if ($gap -eq 1) { continue }
		Write-Ps1ParameterLayoutDiagnostic $Path "Use one space between the closing ] and `$$($parameter.Name.VariablePath.UserPath)." $parameter.Name.Extent
	}
}
