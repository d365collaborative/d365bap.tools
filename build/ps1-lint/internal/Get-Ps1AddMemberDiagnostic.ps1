function Test-Ps1NotePropertyCommand {
	param($Command, [string] $Variable, $PipelineTarget)
	if ($Command.GetCommandName() -ne 'Add-Member') { return $false }
	$elements = @($Command.CommandElements)
	$hasName = $false
	$hasValue = $false
	$memberType = $null
	$target = $PipelineTarget
	for ($index = 0; $index -lt $elements.Count; $index++) {
		$element = $elements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		switch ($element.ParameterName) {
			'NotePropertyName' { $hasName = $true }
			'NotePropertyValue' { $hasValue = $true }
			'Name' { $hasName = $true }
			'Value' { $hasValue = $true }
			'MemberType' {
				if ($index + 1 -lt $elements.Count) { $memberType = $elements[$index + 1].Extent.Text.Trim("'", '"') }
			}
			'InputObject' {
				if ($index + 1 -lt $elements.Count) { $target = $elements[$index + 1] }
			}
		}
	}
	if ($null -ne $memberType -and $memberType -ne 'NoteProperty') { return $false }
	if (-not ($hasName -and $hasValue)) { return $false }
	if ($target -isnot [Management.Automation.Language.VariableExpressionAst]) { return $false }
	$target.VariablePath.UserPath -eq $Variable
}

function Test-Ps1AddMemberStatement {
	param($Statement, [string] $Variable)
	if ($Statement -isnot [Management.Automation.Language.PipelineAst]) { return $false }
	$elements = @($Statement.PipelineElements)
	$command = $null
	$pipelineTarget = $null
	if ($elements.Count -eq 1 -and $elements[0] -is [Management.Automation.Language.CommandAst]) {
		$command = $elements[0]
	}
	elseif ($elements.Count -eq 2 -and $elements[0] -is [Management.Automation.Language.CommandExpressionAst] -and $elements[1] -is [Management.Automation.Language.CommandAst]) {
		$command = $elements[1]
		$pipelineTarget = $elements[0].Expression
	}
	else { return $false }
	Test-Ps1NotePropertyCommand $command $Variable $pipelineTarget
}

function Get-Ps1NotePropertyName {
	param($Statement)
	$command = @($Statement.PipelineElements)[-1]
	$elements = @($command.CommandElements)
	for ($index = 0; $index -lt $elements.Count; $index++) {
		$element = $elements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($element.ParameterName -notin @('NotePropertyName', 'Name')) { continue }
		if ($index + 1 -ge $elements.Count) { return $null }
		return $elements[$index + 1].Extent.Text.Trim("'", '"')
	}
	$null
}

function Get-Ps1AddMemberDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }

	foreach ($loop in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
		$variable = $loop.Variable.VariablePath.UserPath
		$statements = @($loop.Body.Statements)
		if ($statements.Count -eq 0) { continue }

		$addMembers = @($statements | Where-Object { Test-Ps1AddMemberStatement $_ $variable })
		if ($addMembers.Count -eq 0) { continue }

		$pure = $addMembers.Count -eq $statements.Count
		$names = @($addMembers | ForEach-Object { Get-Ps1NotePropertyName $_ } | Where-Object { $_ } | Select-Object -Unique)
		if ($pure) {
			[pscustomobject]@{
				RuleName   = 'PSAvoidAddMemberInLoop'
				Severity   = 'Error'
				ScriptName = [IO.Path]::GetFileName($Path)
				Line       = $loop.Extent.StartLineNumber
				Column     = $loop.Extent.StartColumnNumber
				Message    = 'Add the note properties in the Select-PSFObject or Select-Object projection instead of a foreach loop with Add-Member.'
			}
			continue
		}

		$list = if ($names.Count -gt 0) { $names -join ', ' } else { 'the note properties' }
		[pscustomobject]@{
			RuleName   = 'PSReviewAddMemberInLoop'
			Severity   = 'Warning'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $loop.Extent.StartLineNumber
			Column     = $loop.Extent.StartColumnNumber
			Message    = "Review adding $list in the Select-PSFObject or Select-Object projection after the foreach instead of inside it."
		}
	}
}
