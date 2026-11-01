function Get-Ps1CommentGroup {
	param([hashtable] $Analysis)

	$tokens = $Analysis.Tokens
	$ast = $Analysis.Ast
	$source = $ast.Extent.Text
	$colComments = @($tokens | Where-Object Kind -eq Comment)
	$masked = $source.ToCharArray()
	foreach ($itemComment in $colComments) {
		for ($i = $itemComment.Extent.StartOffset; $i -lt $itemComment.Extent.EndOffset; $i++) {
			if ($masked[$i] -notin @("`r", "`n")) { $masked[$i] = ' ' }
		}
	}

	for ($index = 0; $index -lt $colComments.Count; $index++) {
		$first = $colComments[$index]
		if ($first.Text -match '^#requires\s' -or ($first.Extent.StartOffset -eq 0 -and $first.Text.StartsWith('#!'))) { continue }
		$last = $first
		if (-not $first.Text.StartsWith('<#')) {
			while ($index + 1 -lt $colComments.Count) {
				$next = $colComments[$index + 1]
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
		foreach ($itemFunction in $isolated.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
			if ($null -ne $itemFunction.GetHelpContent()) {
				$isHelp = $true
				$owner = $itemFunction
			}
		}
		$tmpParameters = @(if ($owner -is [Management.Automation.Language.FunctionDefinitionAst]) {
				$owner.Parameters
				$owner.Body.ParamBlock.Parameters
			}
			else { $owner.ParamBlock.Parameters })
		$paramBlock = if ($owner -is [Management.Automation.Language.FunctionDefinitionAst]) { $owner.Body.ParamBlock } else { $owner.ParamBlock }
		$positionalBinding = $true
		foreach ($itemAttribute in $paramBlock.Attributes) {
			if ($itemAttribute.TypeName.FullName -notin @('CmdletBinding', 'CmdletBindingAttribute')) { continue }
			foreach ($itemArgument in $itemAttribute.NamedArguments) {
				if ($itemArgument.ArgumentName -eq 'PositionalBinding' -and $itemArgument.Argument.Extent.Text -ieq '$false') { $positionalBinding = $false }
			}
		}
		$tmpParameterRecords = @()
		foreach ($itemParameter in $tmpParameters) {
			if ($null -eq $itemParameter -or $null -eq $itemParameter.Name) { continue }
			$tmpAliases = @(foreach ($itemAttribute in $itemParameter.Attributes) {
					if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst] -or
						$itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.AliasAttribute]) { continue }
					foreach ($itemArgument in $itemAttribute.PositionalArguments) {
						$itemArgument.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] }, $true) |
						ForEach-Object Value
					}
				})
			$tmpExisting = @($tmpParameterRecords | Where-Object { $_.Name -ieq $itemParameter.Name.VariablePath.UserPath }) | Select-Object -First 1
			if ($null -ne $tmpExisting) {
				$tmpExisting.Aliases = @($tmpExisting.Aliases + $tmpAliases | Select-Object -Unique)
				if ($null -ne $itemParameter.DefaultValue) { $tmpExisting.HasDefault = $true }
			}
			else {
				$position = if ($positionalBinding) { $tmpParameterRecords.Count } else { -1 }
				foreach ($itemAttribute in $itemParameter.Attributes) {
					if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst] -or $itemAttribute.TypeName.FullName -notin @('Parameter', 'ParameterAttribute')) { continue }
					foreach ($itemArgument in $itemAttribute.NamedArguments) {
						if ($itemArgument.ArgumentName -eq 'Position' -and $itemArgument.Argument -is [Management.Automation.Language.ConstantExpressionAst]) { $position = [int]$itemArgument.Argument.Value }
					}
				}
				$tmpParameterRecords += [pscustomobject]@{
					Name            = $itemParameter.Name.VariablePath.UserPath
					Aliases         = @($tmpAliases)
					HasDefault      = ($null -ne $itemParameter.DefaultValue)
					IsSearchDefault = $itemParameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($itemParameter.DefaultValue.Value)
					IsSwitch        = @($itemParameter.Attributes | Where-Object { $_ -is [Management.Automation.Language.TypeConstraintAst] -and $_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter') }).Count -gt 0
					Position        = $position
				}
			}
		}
		$tmpParameterNames = @(foreach ($itemRecord in $tmpParameterRecords) {
				$itemRecord.Name
				$itemRecord.Aliases
			})
		[pscustomobject]@{
			IsHelp           = $isHelp
			ParameterNames   = $tmpParameterNames
			ParameterRecords = @($tmpParameterRecords)
			CommandName      = if ($owner -is [Management.Automation.Language.FunctionDefinitionAst]) { $owner.Name } else { [IO.Path]::GetFileNameWithoutExtension($Analysis.Path) }
			Text             = $source.Substring($first.Extent.StartOffset, $last.Extent.EndOffset - $first.Extent.StartOffset)
			Line             = $first.Extent.StartLineNumber
			Column           = $first.Extent.StartColumnNumber
		}
	}
}
