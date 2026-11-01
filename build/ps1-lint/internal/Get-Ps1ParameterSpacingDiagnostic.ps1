function Get-Ps1ParameterSpacingDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/functions/[^/]+\.ps1$') { return }

	$function = @($Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($Path) })[0]
	if ($null -eq $function -or $null -eq $function.Body.ParamBlock) { return }

	$parameters = @($function.Body.ParamBlock.Parameters)
	for ($index = 1; $index -lt $parameters.Count; $index++) {
		$previous = $parameters[$index - 1]
		$current = $parameters[$index]
		if ($current.Extent.StartLineNumber - $previous.Extent.EndLineNumber -gt 1) { continue }

		[pscustomobject]@{
			RuleName   = 'PSUseBlankLineBeforeParameter'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $current.Extent.StartLineNumber
			Column     = $current.Extent.StartColumnNumber
			Message    = "Add a blank line before the -$($current.Name.VariablePath.UserPath) parameter and its attributes."
		}
	}
}
