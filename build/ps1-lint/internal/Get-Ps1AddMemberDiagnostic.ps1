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
		$elements = @($Command.Parent.PipelineElements)
		$index = [Array]::IndexOf($elements, $Command)
		if ($index -gt 0 -and $elements[$index - 1] -is [Management.Automation.Language.CommandExpressionAst]) {
			$target = $elements[$index - 1].Expression
		}
	}
	$elements = @($Command.CommandElements)
	for ($index = 0; $index -lt $elements.Count; $index++) {
		if ($elements[$index] -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($elements[$index].ParameterName -ne 'InputObject') { continue }
		if ($index + 1 -lt $elements.Count) { $target = $elements[$index + 1] }
	}
	if ($target -isnot [Management.Automation.Language.VariableExpressionAst]) { return $null }
	$target
}

function Get-Ps1AddMemberNoteProperty {
	param($Command)
	$elements = @($Command.CommandElements)
	$name = $null
	$hasNotePropertyName = $false
	$memberType = $null
	for ($index = 0; $index -lt $elements.Count; $index++) {
		$element = $elements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($index + 1 -ge $elements.Count) { continue }
		$value = $elements[$index + 1]
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
	foreach ($member in $Scope.FindAll({ param($node) $node -is [Management.Automation.Language.MemberExpressionAst] }, $true)) {
		if ($null -ne $Exclude -and $member.Extent.StartOffset -ge $Exclude.StartOffset -and $member.Extent.EndOffset -le $Exclude.EndOffset) { continue }
		if ($member.Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($member.Member.Value -ne $PropertyName) { continue }
		$expression = $member.Expression
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
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }

	foreach ($command in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Add-Member' }, $true)) {
		$property = Get-Ps1AddMemberNoteProperty $command
		if ([string]::IsNullOrEmpty($property)) { continue }

		$target = Get-Ps1AddMemberTarget $command
		if ($null -eq $target) { continue }

		$scope = Get-Ps1IterationScope $command
		if ($null -eq $scope) { continue }

		if (Test-Ps1PropertyUsedInScope $scope $target.VariablePath.UserPath $property $command) { continue }

		[pscustomobject]@{
			RuleName   = 'PSAvoidAddMemberInLoop'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $command.Extent.StartLineNumber
			Column     = $command.Extent.StartColumnNumber
			Message    = "Property '$property' is added inside a loop but never read or written inside it. Move it out and add it in the Select-PSFObject or Select-Object projection after the loop."
		}
	}
}
