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
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal/functions)/[^/]+\.ps1$') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }

	$function = @($Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($Path) })[0]
	if ($null -eq $function -or $null -eq $function.Body.ParamBlock) { return }

	$colParameters = @($function.Body.ParamBlock.Parameters)
	for ($index = 0; $index -lt $colParameters.Count; $index++) {
		$itemParameter = $colParameters[$index]
		$name = $itemParameter.Name.VariablePath.UserPath

		if ($index -gt 0) {
			$previous = $colParameters[$index - 1]
			if ($itemParameter.Extent.StartLineNumber - $previous.Extent.EndLineNumber -le 1) {
				Write-Ps1ParameterLayoutDiagnostic $Path "Add a blank line before the -$name parameter and its attributes." $itemParameter.Extent
			}
		}

		$tmpItems = @(
			foreach ($itemAttribute in $itemParameter.Attributes) {
				$rank = if ($itemAttribute -is [Management.Automation.Language.TypeConstraintAst]) {
					3
				}
				elseif ($itemAttribute.TypeName.GetReflectionAttributeType() -eq [Management.Automation.ParameterAttribute]) {
					0
				}
				elseif ($itemAttribute.TypeName.GetReflectionAttributeType() -eq [Management.Automation.ValidateSetAttribute]) {
					1
				}
				else { 2 }
				[pscustomobject]@{ Rank = $rank; Ast = $itemAttribute }
			}
			[pscustomobject]@{ Rank = 4; Ast = $itemParameter.Name }
		)

		$ordered = $true
		for ($itemIndex = 1; $itemIndex -lt $tmpItems.Count; $itemIndex++) {
			$previousItem = $tmpItems[$itemIndex - 1]
			$currentItem = $tmpItems[$itemIndex]
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

		$type = @($tmpItems | Where-Object { $_.Rank -eq 3 })[-1]
		if ($null -ne $type -and $itemParameter.Name.Extent.StartLineNumber - $type.Ast.Extent.EndLineNumber -eq 1) {
			Write-Ps1ParameterLayoutDiagnostic $Path "Keep the type constraint and parameter name on the same line for -$name." $itemParameter.Name.Extent
		}
	}

	foreach ($itemParameter in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		$tmpAttributes = @($itemParameter.Attributes)
		if ($tmpAttributes.Count -eq 0) { continue }
		$last = $tmpAttributes[-1]
		if ($itemParameter.Name.Extent.StartLineNumber -ne $last.Extent.EndLineNumber) { continue }
		$gap = $itemParameter.Name.Extent.StartColumnNumber - $last.Extent.EndColumnNumber
		if ($gap -eq 1) { continue }
		Write-Ps1ParameterLayoutDiagnostic $Path "Use one space between the closing ] and `$$($itemParameter.Name.VariablePath.UserPath)." $itemParameter.Name.Extent
	}
}
