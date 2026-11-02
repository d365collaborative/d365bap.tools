function Get-Ps1FunctionInterruptOwner {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { $parent; return }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1FunctionInterruptCommandName {
	param($Command)

	$name = $Command.GetCommandName()
	if ($null -eq $name) { return }
	($name -split '\\')[-1]
}

function Get-Ps1FunctionInterruptParameter {
	param($Command, [string] $Name)

	$colElements = @($Command.CommandElements)
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		$tmpElement = $colElements[$index]
		if ($tmpElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if (-not $Name.StartsWith($tmpElement.ParameterName, [StringComparison]::OrdinalIgnoreCase)) { continue }

		$tmpArgument = $null
		if ($null -ne $tmpElement.Argument) { $tmpArgument = $tmpElement.Argument }
		elseif ($index + 1 -lt $colElements.Count) { $tmpArgument = $colElements[$index + 1] }

		$tmpArgument
		return
	}
}

function Test-Ps1FunctionInterruptStopTargetsCaller {
	param($Stop)

	$stepsArgument = Get-Ps1FunctionInterruptParameter -Command $Stop `
		-Name 'StepsUpward'
	if ($stepsArgument -is [Management.Automation.Language.ConstantExpressionAst] -and
		"$($stepsArgument.Value)" -match '^[1-9][0-9]*$') {
		$true
		return
	}

	$enableArgument = Get-Ps1FunctionInterruptParameter -Command $Stop `
		-Name 'EnableException'
	if ($enableArgument -is [Management.Automation.Language.VariableExpressionAst] -and
		$enableArgument.VariablePath.UserPath -ieq 'true') {
		$true
		return
	}
	if ($enableArgument -is [Management.Automation.Language.ConstantExpressionAst] -and
		"$($enableArgument.Value)" -match '^(?i:true|1)$') {
		$true
		return
	}

	$false
}

function Get-Ps1FunctionInterruptGuardBlock {
	param($Stop, $Owner)

	$itemBlock = $Stop.Parent
	while ($null -ne $itemBlock) {
		if ($itemBlock -is [Management.Automation.Language.StatementBlockAst] -or
			$itemBlock -is [Management.Automation.Language.NamedBlockAst]) {
			if ($itemBlock.Parent -is [Management.Automation.Language.ScriptBlockAst]) {
				if ($itemBlock -eq $Owner.Body.ProcessBlock) {
					$itemBlock
					return
				}

				return
			}

			$itemBlock
			return
		}

		$itemBlock = $itemBlock.Parent
	}

	$null
}

function Get-Ps1FunctionInterruptContainingStatement {
	param($Node)

	$itemNode = $Node
	while ($null -ne $itemNode.Parent -and
		$itemNode.Parent -isnot [Management.Automation.Language.StatementBlockAst] -and
		$itemNode.Parent -isnot [Management.Automation.Language.NamedBlockAst]) {
		$itemNode = $itemNode.Parent
	}
	if ($null -eq $itemNode.Parent) { return }

	$itemNode
}

function Test-Ps1FunctionInterruptStopGuard {
	param($Statements, $Check, $Owner)

	foreach ($itemStatement in $Statements) {
		foreach ($itemStop in $itemStatement.FindAll({
					param($Node)
					$Node -is [Management.Automation.Language.CommandAst] -and
					(Get-Ps1FunctionInterruptCommandName $Node) -eq 'Stop-PSFFunction'
				}, $true)) {
			if ($itemStop.Extent.StartOffset -ge $Check.Extent.StartOffset) { continue }
			if ((Get-Ps1FunctionInterruptOwner -Node $itemStop) -ne $Owner) { continue }

			if (Test-Ps1FunctionInterruptStopTargetsCaller -Stop $itemStop) {
				$true
				return
			}

			$itemBlock = Get-Ps1FunctionInterruptGuardBlock -Stop $itemStop `
				-Owner $Owner
			if ($null -eq $itemBlock) { continue }

			foreach ($itemReturn in @($itemBlock.Statements | Where-Object {
						$_ -is [Management.Automation.Language.ReturnStatementAst] -and
						$_.Extent.StartOffset -gt $itemStop.Extent.StartOffset -and
						$_.Extent.StartOffset -lt $Check.Extent.StartOffset
					})) {
				$true
				return
			}
		}
	}

	$false
}

function Get-Ps1FunctionInterruptDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemFunction in @(Get-Ps1AstNode $Analysis FunctionDefinitionAst)) {
		$objProcess = $itemFunction.Body.ProcessBlock
		if ($null -eq $objProcess) { continue }

		$tmpPreceding = [System.Collections.Generic.List[object]]::new()
		if ($null -ne $itemFunction.Body.DynamicParamBlock) {
			foreach ($itemStatement in $itemFunction.Body.DynamicParamBlock.Statements) { $tmpPreceding.Add($itemStatement) }
		}
		if ($null -ne $itemFunction.Body.BeginBlock) {
			foreach ($itemStatement in $itemFunction.Body.BeginBlock.Statements) { $tmpPreceding.Add($itemStatement) }
		}

		foreach ($itemStatement in $objProcess.Statements) {
			$hasPrecedingCommand = @($tmpPreceding | Where-Object {
					@($_.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)).Count -gt 0
				}).Count -gt 0

			foreach ($itemCommand in $itemStatement.FindAll({
						param($Node)
						$Node -is [Management.Automation.Language.CommandAst] -and
						(Get-Ps1FunctionInterruptCommandName $Node) -eq 'Test-PSFFunctionInterrupt'
					}, $true)) {
				if ((Get-Ps1FunctionInterruptOwner -Node $itemCommand) -ne $itemFunction) { continue }

				$tmpEnclosing = Get-Ps1FunctionInterruptContainingStatement -Node $itemCommand
				if ($null -ne $tmpEnclosing -and $null -ne $tmpEnclosing.Parent) {
					$tmpSiblings = @($tmpEnclosing.Parent.Statements)
					$index = [Array]::IndexOf($tmpSiblings, $tmpEnclosing)
					if ($index -gt 0) {
						$tmpPrevious = $tmpSiblings[$index - 1]
						$isGuard = $tmpPrevious -is [Management.Automation.Language.IfStatementAst] -or
						$tmpPrevious -is [Management.Automation.Language.TryStatementAst]
						$hasDirectStop = $tmpPrevious -is [Management.Automation.Language.PipelineAst] -and
						@($tmpPrevious.FindAll({
									param($Node)
									$Node -is [Management.Automation.Language.CommandAst] -and
									(Get-Ps1FunctionInterruptCommandName $Node) -eq 'Stop-PSFFunction'
								}, $true)).Count -gt 0

						if (($isGuard -or $hasDirectStop) -and
							(Test-Ps1FunctionInterruptStopGuard -Statements @($tmpPrevious) `
								-Check $itemCommand `
								-Owner $itemFunction)) {
							New-Ps1Diagnostic $Path 'PSAvoidOrphanPSFFunctionInterruptCheck' 'The preceding Stop-PSFFunction guard returns or targets the caller before this check, so the check cannot observe that interrupt. Remove the Test-PSFFunctionInterrupt check.' $itemCommand.Extent
							continue
						}
					}
				}

				if ($hasPrecedingCommand) { continue }

				$tmpPriorInStatement = @($itemStatement.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true) | Where-Object {
						$_.Extent.StartOffset -lt $itemCommand.Extent.StartOffset -and
						(Get-Ps1FunctionInterruptCommandName $_) -ne 'Test-PSFFunctionInterrupt'
					})
				if ($tmpPriorInStatement.Count -gt 0) { continue }

				New-Ps1Diagnostic $Path 'PSAvoidOrphanPSFFunctionInterruptCheck' 'Test-PSFFunctionInterrupt in a process block has no preceding command that can interrupt the function. Move the check after the command that can stop, or remove it.' $itemCommand.Extent
			}

			$tmpPreceding.Add($itemStatement)
		}
	}
}
