function Get-Ps1DirectStringCheckValue {
	param($Argument)

	if ($Argument -isnot [Management.Automation.Language.ExpandableStringExpressionAst]) { $null; return }

	$colNested = @($Argument.NestedExpressions)
	if ($colNested.Count -ne 1) { $null; return }
	if ($Argument.Value -ne $colNested[0].Extent.Text) { $null; return }

	$itemValue = $colNested[0]
	if ($itemValue -is [Management.Automation.Language.SubExpressionAst]) {
		$colStatements = @($itemValue.SubExpression.Statements)
		if ($colStatements.Count -ne 1) { $null; return }
		$colStatements[0].Extent.Text
		return
	}

	$itemValue.Extent.Text
}

function Get-Ps1DirectStringCheckDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemInvoke in @(Get-Ps1AstNode $Analysis InvokeMemberExpressionAst)) {
		if (-not $itemInvoke.Static) { continue }
		if ($itemInvoke.Expression -isnot [Management.Automation.Language.TypeExpressionAst]) { continue }
		if ($itemInvoke.Expression.TypeName.FullName -notmatch '^(?i)(System\.)?String$') { continue }
		if ($itemInvoke.Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($itemInvoke.Member.Value -notin @('IsNullOrWhiteSpace', 'IsNullOrEmpty')) { continue }

		foreach ($itemArgument in $itemInvoke.Arguments) {
			$valueText = Get-Ps1DirectStringCheckValue -Argument $itemArgument
			if ($null -eq $valueText) { continue }

			New-Ps1Diagnostic $Path 'PSUseDirectValueInStringCheck' "[string]::$($itemInvoke.Member.Value) already converts the value to a string. Pass the value directly: [string]::$($itemInvoke.Member.Value)($valueText)." $itemArgument.Extent
		}
	}
}
