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

function Get-Ps1AddMemberDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }

	foreach ($loop in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
		$variable = $loop.Variable.VariablePath.UserPath
		$statements = @($loop.Body.Statements)
		if ($statements.Count -eq 0) { continue }

		$projectable = $true
		foreach ($statement in $statements) {
			if ($statement -isnot [Management.Automation.Language.PipelineAst]) { $projectable = $false; break }
			$elements = @($statement.PipelineElements)
			$command = $null
			$pipelineTarget = $null
			if ($elements.Count -eq 1 -and $elements[0] -is [Management.Automation.Language.CommandAst]) {
				$command = $elements[0]
			}
			elseif ($elements.Count -eq 2 -and $elements[0] -is [Management.Automation.Language.CommandExpressionAst] -and $elements[1] -is [Management.Automation.Language.CommandAst]) {
				$command = $elements[1]
				$pipelineTarget = $elements[0].Expression
			}
			else { $projectable = $false; break }
			if (-not (Test-Ps1NotePropertyCommand $command $variable $pipelineTarget)) { $projectable = $false; break }
		}
		if (-not $projectable) { continue }

		[pscustomobject]@{
			RuleName   = 'PSAvoidAddMemberInLoop'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $loop.Extent.StartLineNumber
			Column     = $loop.Extent.StartColumnNumber
			Message    = 'Add the note properties in the Select-PSFObject or Select-Object projection instead of a foreach loop with Add-Member.'
		}
	}
}
