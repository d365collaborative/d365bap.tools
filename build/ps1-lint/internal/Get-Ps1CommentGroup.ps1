function Get-Ps1CommentGroup {
	param([hashtable] $Analysis)

	$tokens = $Analysis.Tokens
	$ast = $Analysis.Ast
	$source = $ast.Extent.Text
	$comments = @($tokens | Where-Object Kind -eq Comment)
	$masked = $source.ToCharArray()
	foreach ($comment in $comments) {
		for ($i = $comment.Extent.StartOffset; $i -lt $comment.Extent.EndOffset; $i++) {
			if ($masked[$i] -notin @("`r", "`n")) { $masked[$i] = ' ' }
		}
	}

	for ($index = 0; $index -lt $comments.Count; $index++) {
		$first = $comments[$index]
		if ($first.Text -match '^#requires\s' -or ($first.Extent.StartOffset -eq 0 -and $first.Text.StartsWith('#!'))) { continue }
		$last = $first
		if (-not $first.Text.StartsWith('<#')) {
			while ($index + 1 -lt $comments.Count) {
				$next = $comments[$index + 1]
				$gap = $source.Substring($last.Extent.EndOffset, $next.Extent.StartOffset - $last.Extent.EndOffset)
				if ($next.Text.StartsWith('<#') -or $next.Text -match '^#requires\s' -or
					$next.Extent.StartLineNumber -ne $last.Extent.EndLineNumber + 1 -or $gap -match '\S') { break }
				$index++
				$last = $next
			}
		}

		$candidate = $masked.Clone()
		for ($i = $first.Extent.StartOffset; $i -lt $last.Extent.EndOffset; $i++) { $candidate[$i] = $source[$i] }
		$isolated = [Management.Automation.Language.Parser]::ParseInput((-join $candidate), [ref]$null, [ref]$null)
		$isHelp = $null -ne $isolated.GetHelpContent()
		$owner = $isolated
		foreach ($function in $isolated.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
			if ($null -ne $function.GetHelpContent()) {
				$isHelp = $true
				$owner = $function
			}
		}
		$parameters = @(if ($owner -is [Management.Automation.Language.FunctionDefinitionAst]) {
				$owner.Parameters
				$owner.Body.ParamBlock.Parameters
			}
			else { $owner.ParamBlock.Parameters })
		$paramBlock = if ($owner -is [Management.Automation.Language.FunctionDefinitionAst]) { $owner.Body.ParamBlock } else { $owner.ParamBlock }
		$positionalBinding = $true
		foreach ($attribute in $paramBlock.Attributes) {
			if ($attribute.TypeName.FullName -notin @('CmdletBinding', 'CmdletBindingAttribute')) { continue }
			foreach ($argument in $attribute.NamedArguments) {
				if ($argument.ArgumentName -eq 'PositionalBinding' -and $argument.Argument.Extent.Text -ieq '$false') { $positionalBinding = $false }
			}
		}
		$parameterRecords = @()
		foreach ($parameter in $parameters) {
			if ($null -eq $parameter -or $null -eq $parameter.Name) { continue }
			$aliases = @(foreach ($attribute in $parameter.Attributes) {
					if ($attribute -isnot [Management.Automation.Language.AttributeAst] -or
						$attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.AliasAttribute]) { continue }
					foreach ($argument in $attribute.PositionalArguments) {
						$argument.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] }, $true) |
						ForEach-Object Value
					}
				})
			$existing = @($parameterRecords | Where-Object { $_.Name -ieq $parameter.Name.VariablePath.UserPath }) | Select-Object -First 1
			if ($null -ne $existing) {
				$existing.Aliases = @($existing.Aliases + $aliases | Select-Object -Unique)
				if ($null -ne $parameter.DefaultValue) { $existing.HasDefault = $true }
			}
			else {
				$position = if ($positionalBinding) { $parameterRecords.Count } else { -1 }
				foreach ($attribute in $parameter.Attributes) {
					if ($attribute -isnot [Management.Automation.Language.AttributeAst] -or $attribute.TypeName.FullName -notin @('Parameter', 'ParameterAttribute')) { continue }
					foreach ($argument in $attribute.NamedArguments) {
						if ($argument.ArgumentName -eq 'Position' -and $argument.Argument -is [Management.Automation.Language.ConstantExpressionAst]) { $position = [int]$argument.Argument.Value }
					}
				}
				$parameterRecords += [pscustomobject]@{
					Name            = $parameter.Name.VariablePath.UserPath
					Aliases         = @($aliases)
					HasDefault      = ($null -ne $parameter.DefaultValue)
					IsSearchDefault = $parameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($parameter.DefaultValue.Value)
					IsSwitch        = @($parameter.Attributes | Where-Object { $_ -is [Management.Automation.Language.TypeConstraintAst] -and $_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter') }).Count -gt 0
					Position        = $position
				}
			}
		}
		$parameterNames = @(foreach ($record in $parameterRecords) {
				$record.Name
				$record.Aliases
			})
		[pscustomobject]@{
			IsHelp           = $isHelp
			ParameterNames   = $parameterNames
			ParameterRecords = @($parameterRecords)
			CommandName      = if ($owner -is [Management.Automation.Language.FunctionDefinitionAst]) { $owner.Name } else { [IO.Path]::GetFileNameWithoutExtension($Analysis.Path) }
			Text             = $source.Substring($first.Extent.StartOffset, $last.Extent.EndOffset - $first.Extent.StartOffset)
			Line             = $first.Extent.StartLineNumber
			Column           = $first.Extent.StartColumnNumber
		}
	}
}
