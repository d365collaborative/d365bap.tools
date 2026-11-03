function Get-Ps1IterationScope {
	param($Node)
	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return }
		if ($parent -is [Management.Automation.Language.ScriptBlockAst] -and
			$parent.Parent -is [Management.Automation.Language.ScriptBlockExpressionAst]) {
			$invocation = $parent.Parent.Parent
			$isIterationCommand = $invocation -is [Management.Automation.Language.CommandAst] -and
			$invocation.GetCommandName() -in @('ForEach-Object', 'Microsoft.PowerShell.Core\ForEach-Object')
			$isIterationMethod = $invocation -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
			$invocation.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and $invocation.Member.Value -ieq 'ForEach'
			if (-not $isIterationCommand -and -not $isIterationMethod) { return }
		}
		if ($parent -is [Management.Automation.Language.ForEachStatementAst] -or
			$parent -is [Management.Automation.Language.ForStatementAst] -or
			$parent -is [Management.Automation.Language.WhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoWhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoUntilStatementAst]) {
			$parent; return
		}
		if ($parent -is [Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -in @('ForEach-Object', 'Microsoft.PowerShell.Core\ForEach-Object')) { $parent; return }
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
		if ($null -ne $colElements[$index].Argument) { $target = $colElements[$index].Argument } elseif ($index + 1 -lt $colElements.Count) { $target = $colElements[$index + 1] }
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
	$hasMemberType = $false
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		$element = $colElements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($element.ParameterName -in @('NotePropertyName', 'NotePropertyValue')) { $hasNotePropertyName = $true }
		if ($element.ParameterName -eq 'MemberType') { $hasMemberType = $true }
		$value = $element.Argument
		if ($null -eq $value -and $index + 1 -lt $colElements.Count) { $value = $colElements[$index + 1] }
		if ($value -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		switch ($element.ParameterName) {
			'NotePropertyName' { $hasNotePropertyName = $true; $name = $value.Value }
			'MemberType' { $memberType = $value.Value }
			'Name' { $name = $value.Value }
		}
	}
	if ($hasMemberType -and $null -eq $memberType) { @{ Name = $null }; return }
	if (-not $hasNotePropertyName -and $memberType -ne 'NoteProperty') { $null; return }
	@{ Name = $name }
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
		if ($name -ne $Variable -and -not ($name -in @('_', 'PSItem') -and $Variable -in @('_', 'PSItem'))) { continue }
		$owner = $itemMember.Parent
		while ($null -ne $owner -and $owner -isnot [Management.Automation.Language.ScriptBlockAst]) { $owner = $owner.Parent }
		$commandOwner = $Exclude.Parent
		while ($null -ne $commandOwner -and $commandOwner -isnot [Management.Automation.Language.ScriptBlockAst]) { $commandOwner = $commandOwner.Parent }
		if ($owner -ne $commandOwner) { continue }
		$writeTarget = $itemMember
		while ($writeTarget.Parent -is [Management.Automation.Language.ArrayLiteralAst]) { $writeTarget = $writeTarget.Parent }
		if ($writeTarget.Parent -is [Management.Automation.Language.AssignmentStatementAst] -and
			$writeTarget.Parent.Left -eq $writeTarget -and $writeTarget.Parent.Operator -eq 'Equals') { continue }
		$true; return
	}
	$false
}

function Get-Ps1AddMemberDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleOrLintTooling')) { return }

	$colCommands = @(Get-Ps1AstNode $Analysis CommandAst | Where-Object { $_.GetCommandName() -in @('Add-Member', 'Microsoft.PowerShell.Utility\Add-Member') })
	foreach ($itemCommand in $colCommands) {
		$scope = Get-Ps1IterationScope $itemCommand
		if ($null -eq $scope) { continue }
		$tmpParameters = @($itemCommand.CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] })
		$tmpKnownNames = @('InputObject', 'NotePropertyName', 'NotePropertyValue', 'MemberType', 'Name', 'Value', 'SecondValue', 'Force', 'PassThru', 'TypeName', 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ProgressAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')
		$unsupportedParameter = @($tmpParameters | Where-Object { $_.ParameterName -notin $tmpKnownNames }).Count -gt 0
		$duplicates = @($tmpParameters | Group-Object ParameterName | Where-Object Count -gt 1).Count -gt 0
		if ($unsupportedParameter -or $duplicates -or $tmpParameters.Count -eq 0) {
			New-Ps1Diagnostic $Path 'PSAvoidAddMemberInLoop' 'Unsupported Add-Member parameters inside a loop. Use full parameter names and one literal note property at a time.' $itemCommand.Extent
			continue
		}
		$note = Get-Ps1AddMemberNoteProperty $itemCommand
		$splat = @($itemCommand.CommandElements | Where-Object { $_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.Splatted }).Count -gt 0
		if ($null -eq $note -and -not $splat) { continue }
		$target = Get-Ps1AddMemberTarget $itemCommand
		if ($splat -or $null -eq $target -or [string]::IsNullOrEmpty($note.Name)) {
			New-Ps1Diagnostic $Path 'PSAvoidAddMemberInLoop' 'Unsupported Add-Member form inside a loop; use a literal note property name and variable target for this rule.' $itemCommand.Extent
			continue
		}
		$property = $note.Name
		if (Test-Ps1PropertyUsedInScope $scope $target.VariablePath.UserPath $property $itemCommand) { continue }
		New-Ps1Diagnostic $Path 'PSAvoidAddMemberInLoop' "Property '$property' is added inside a loop but has no recognized read inside it. Review whether a projection after the loop is appropriate." $itemCommand.Extent
	}
}
