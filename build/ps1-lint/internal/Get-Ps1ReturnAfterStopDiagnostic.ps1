function Test-Ps1StopParameterPresent {
	param($Command, [string] $Name)

	@($Command.CommandElements | Where-Object {
			$_ -is [Management.Automation.Language.CommandParameterAst] -and
			$_.ParameterName -ieq $Name
		}).Count -gt 0
}

function Test-Ps1StopEnableException {
	param($Command)

	$colElements = @($Command.CommandElements)
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		$element = $colElements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($element.ParameterName -ine 'EnableException') { continue }

		if (-not ($null -eq $element.Argument)) {
			"$($element.Argument.Extent.Text)" -ieq '$true'
			return
		}
		if ($index + 1 -lt $colElements.Count -and
			$colElements[$index + 1] -isnot [Management.Automation.Language.CommandParameterAst]) {
			"$($colElements[$index + 1].Extent.Text)" -ieq '$true'
			return
		}
		$true
		return
	}
	$false
}

function Test-Ps1PlainStop {
	param($Command)

	if (Test-Ps1StopParameterPresent -Command $Command `
			-Name 'StepsUpward') { $false; return }
	if (Test-Ps1StopParameterPresent -Command $Command `
			-Name 'Continue') { $false; return }
	if (Test-Ps1StopEnableException -Command $Command) { $false; return }

	$true
}

function Test-Ps1ExitStatement {
	param($Statement)

	$Statement -is [Management.Automation.Language.ReturnStatementAst] -or
	$Statement -is [Management.Automation.Language.ThrowStatementAst] -or
	$Statement -is [Management.Automation.Language.ExitStatementAst]
}

function Test-Ps1StopFollowedByExit {
	param($Command)

	$statement = $Command
	while ($null -ne $statement.Parent -and
		$statement.Parent -isnot [Management.Automation.Language.StatementBlockAst] -and
		$statement.Parent -isnot [Management.Automation.Language.NamedBlockAst]) {
		$statement = $statement.Parent
	}

	while ($null -ne $statement.Parent) {
		$parent = $statement.Parent
		if ($parent -is [Management.Automation.Language.StatementBlockAst] -or
			$parent -is [Management.Automation.Language.NamedBlockAst]) {
			$tmpStatements = @($parent.Statements)
			$index = [Array]::IndexOf($tmpStatements, $statement)
			if ($index -ge 0 -and ($index + 1) -lt $tmpStatements.Count) {
				Test-Ps1ExitStatement -Statement $tmpStatements[$index + 1]
				return
			}
			if ($parent -is [Management.Automation.Language.NamedBlockAst]) { $true; return }

			$statement = $parent.Parent
			continue
		}

		$statement = $parent
	}

	$true
}

function Get-Ps1ReturnAfterStopDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine 'Stop-PSFFunction') { continue }
		if (-not (Test-Ps1PlainStop -Command $itemCommand)) { continue }
		if (Test-Ps1StopFollowedByExit -Command $itemCommand) { continue }

		New-Ps1Diagnostic $Path 'PSUseReturnAfterStopPSFFunction' 'A plain Stop-PSFFunction must be followed by return, throw, or exit. Add a return, or pass -StepsUpward, -EnableException, or -Continue when continuing is intended.' $itemCommand.Extent
	}
}
