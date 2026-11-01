function Get-Ps1IterationScope {
	param($Node)
	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.ForEachStatementAst] -or
			$parent -is [Management.Automation.Language.ForStatementAst] -or
			$parent -is [Management.Automation.Language.WhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoWhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoUntilStatementAst]) {
			return $parent
		}
		if ($parent -is [Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -eq 'ForEach-Object') { return $parent }
		if ($parent -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
			$parent.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
			$parent.Member.Value -eq 'ForEach') {
			return $parent
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
	if ($target -isnot [Management.Automation.Language.VariableExpressionAst]) { return $null }
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
	if (-not $hasNotePropertyName -and $memberType -ne 'NoteProperty') { return $null }
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
		if ($name -eq $Variable -or $name -in @('_', 'PSItem')) { return $true }
	}
	$false
}

function Get-Ps1AddMemberDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isModuleFile = $normalized -match '/d365bap\.tools/(functions|internal)/'
	$isLintTooling = $normalized -match '/build/ps1-lint/'
	if (-not $isModuleFile -and -not $isLintTooling) { return }

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Add-Member' }, $true)) {
		$property = Get-Ps1AddMemberNoteProperty $itemCommand
		if ([string]::IsNullOrEmpty($property)) { continue }

		$target = Get-Ps1AddMemberTarget $itemCommand
		if ($null -eq $target) { continue }

		$scope = Get-Ps1IterationScope $itemCommand
		if ($null -eq $scope) { continue }

		if (Test-Ps1PropertyUsedInScope $scope $target.VariablePath.UserPath $property $itemCommand) { continue }

		[pscustomobject]@{
			RuleName   = 'PSAvoidAddMemberInLoop'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $itemCommand.Extent.StartLineNumber
			Column     = $itemCommand.Extent.StartColumnNumber
			Message    = "Property '$property' is added inside a loop but never read or written inside it. Move it out and add it in the Select-PSFObject or Select-Object projection after the loop."
		}
	}
}
