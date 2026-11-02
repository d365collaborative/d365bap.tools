function Get-Ps1IterationScope {
	param($Node)
	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.ForEachStatementAst] -or
			$parent -is [Management.Automation.Language.ForStatementAst] -or
			$parent -is [Management.Automation.Language.WhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoWhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoUntilStatementAst]) {
			$parent; return
		}
		if ($parent -is [Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -eq 'ForEach-Object') { $parent; return }
		if ($parent -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
			$parent.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
			$parent.Member.Value -eq 'ForEach') {
			$parent; return
		}
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1AddMemberTarget {
	param($Command)
	$target = $null
	if ($Command.Parent -is [Management.Automation.Language.PipelineAst]) {
		$colElements = @($Command.Parent.PipelineElements)
		$index = [Array]::IndexOf($colElements, $Command)
		if ($index -gt 0 -and $colElements[$index - 1] -is [Management.Automation.Language.CommandExpressionAst]) {
			$target = $colElements[$index - 1].Expression
		}
	}
	$colElements = @($Command.CommandElements)
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		if ($colElements[$index] -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($colElements[$index].ParameterName -ne 'InputObject') { continue }
		if ($index + 1 -lt $colElements.Count) { $target = $colElements[$index + 1] }
	}
	if ($target -isnot [Management.Automation.Language.VariableExpressionAst]) { $null; return }
	$target
}

function Get-Ps1AddMemberNoteProperty {
	param($Command)
	$colElements = @($Command.CommandElements)
	$name = $null
	$hasNotePropertyName = $false
	$memberType = $null
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		$element = $colElements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($index + 1 -ge $colElements.Count) { continue }
		$value = $colElements[$index + 1]
		if ($value -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		switch ($element.ParameterName) {
			'NotePropertyName' { $hasNotePropertyName = $true; $name = $value.Value }
			'MemberType' { $memberType = $value.Value }
			'Name' { $name = $value.Value }
		}
	}
	if (-not $hasNotePropertyName -and $memberType -ne 'NoteProperty') { $null; return }
	$name
}

function Test-Ps1PropertyUsedInScope {
	param($Scope, [string] $Variable, [string] $PropertyName, $Exclude)
	foreach ($itemMember in $Scope.FindAll({ param($node) $node -is [Management.Automation.Language.MemberExpressionAst] }, $true)) {
		if ($null -ne $Exclude -and $itemMember.Extent.StartOffset -ge $Exclude.StartOffset -and $itemMember.Extent.EndOffset -le $Exclude.EndOffset) { continue }
		if ($itemMember.Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($itemMember.Member.Value -ne $PropertyName) { continue }
		$expression = $itemMember.Expression
		if ($expression -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
		$name = $expression.VariablePath.UserPath
		if ($name -eq $Variable -or $name -in @('_', 'PSItem')) { $true; return }
	}
	$false
}

function Get-Ps1AddMemberDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleOrLintTooling')) { return }

	$colCommands = @(Get-Ps1AstNode $Analysis CommandAst | Where-Object { $_.GetCommandName() -eq 'Add-Member' })
	foreach ($itemCommand in $colCommands) {
		$property = Get-Ps1AddMemberNoteProperty $itemCommand
		if ([string]::IsNullOrEmpty($property)) { continue }

		$target = Get-Ps1AddMemberTarget $itemCommand
		if ($null -eq $target) { continue }

		$scope = Get-Ps1IterationScope $itemCommand
		if ($null -eq $scope) { continue }

		if (Test-Ps1PropertyUsedInScope $scope $target.VariablePath.UserPath $property $itemCommand) { continue }

		New-Ps1Diagnostic $Path 'PSAvoidAddMemberInLoop' "Property '$property' is added inside a loop but never read or written inside it. Move it out and add it in the Select-PSFObject or Select-Object projection after the loop." $itemCommand.Extent
	}
}
