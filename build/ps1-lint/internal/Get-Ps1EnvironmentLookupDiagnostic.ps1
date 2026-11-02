$script:Ps1EnvironmentLookupExemptions = @(
	'Get-BapEnvironment.ps1'
	'Get-UnifiedEnvironment.ps1'
	'Get-Environment.ps1'
)

function Get-Ps1EnvironmentOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { $parent; return }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1EnvironmentAssignment {
	param($Call)

	$node = $Call.Parent
	while ($null -ne $node) {
		if ($node -is [Management.Automation.Language.AssignmentStatementAst]) { $node; return }
		if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { return }
		$node = $node.Parent
	}
	$null
}

function Test-Ps1EnvironmentTryAncestor {
	param($Call)

	$node = $Call.Parent
	while ($null -ne $node) {
		if ($node -is [Management.Automation.Language.TryStatementAst]) { $true; return }
		if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { $false; return }
		$node = $node.Parent
	}
	$false
}

function Get-Ps1EnvironmentInterruptCheck {
	param($Call)

	$statement = $Call
	while ($null -ne $statement -and
		$statement.Parent -isnot [Management.Automation.Language.StatementBlockAst] -and
		$statement.Parent -isnot [Management.Automation.Language.NamedBlockAst]) {
		$statement = $statement.Parent
	}
	if ($null -eq $statement) { return }

	$colStatements = @($statement.Parent.Statements)
	$index = [Array]::IndexOf($colStatements, $statement)
	if ($index -lt 0 -or ($index + 1) -ge $colStatements.Count) { return }

	$owner = Get-Ps1EnvironmentOwnerFunction -Node $Call
	foreach ($itemNode in $colStatements[$index + 1].FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.CommandAst] -and
				($Node.GetCommandName() -split '\\')[-1] -eq 'Test-PSFFunctionInterrupt'
			}, $true)) {
		if ((Get-Ps1EnvironmentOwnerFunction -Node $itemNode) -ne $owner) { continue }
		$itemNode
	}
}

function Get-Ps1EnvironmentNullCheck {
	param($Owner, [string] $Name)

	foreach ($itemNode in $Owner.Body.FindAll({ param($n) $n -is [Management.Automation.Language.BinaryExpressionAst] -and "$($n.Operator)" -in @('Ieq', 'Ine') }, $true)) {
		if ((Get-Ps1EnvironmentOwnerFunction -Node $itemNode) -ne $Owner) { continue }

		$left = $itemNode.Left
		$right = $itemNode.Right
		$isNullLeft = $left -is [Management.Automation.Language.VariableExpressionAst] -and $left.VariablePath.UserPath -ieq 'null'
		$isNullRight = $right -is [Management.Automation.Language.VariableExpressionAst] -and $right.VariablePath.UserPath -ieq 'null'
		$isNameLeft = $left -is [Management.Automation.Language.VariableExpressionAst] -and $left.VariablePath.UserPath -ieq $Name
		$isNameRight = $right -is [Management.Automation.Language.VariableExpressionAst] -and $right.VariablePath.UserPath -ieq $Name

		if (($isNullLeft -and $isNameRight) -or ($isNullRight -and $isNameLeft)) { $itemNode }
	}
}

function Get-Ps1EnvironmentLookupDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$scope = $Analysis.Scope
	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }
	if ($scope.FileName -in $script:Ps1EnvironmentLookupExemptions) { return }

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }

		$commandName = ($commandName -split '\\')[-1]

		if ($commandName -eq 'Get-Environment') {
			if (Test-Ps1EnvironmentTryAncestor -Call $itemCommand) {
				New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' 'Do not wrap Get-Environment in try/catch. It stops execution when no environment matches; let that surface.' $itemCommand.Extent
			}

			$assignment = Get-Ps1EnvironmentAssignment -Call $itemCommand
			$variableName = $null

			if ($null -eq $assignment) {
				New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' 'Assign Get-Environment to a local variable named $envObj so later code can use the environment directly.' $itemCommand.Extent
			}
			elseif ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) {
				New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' 'Assign Get-Environment to a local variable named $envObj so later code can use the environment directly.' $assignment.Extent
			}
			else {
				$variableName = $assignment.Left.VariablePath.UserPath
				if ($variableName -notmatch '^envObj') {
					New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' ('Assign Get-Environment to a local variable named $envObj (found $' + $variableName + ').') $assignment.Left.Extent
				}
			}

			if ($null -ne $variableName) {
				$owner = Get-Ps1EnvironmentOwnerFunction -Node $itemCommand
				if ($null -ne $owner) {
					foreach ($itemCheck in @(Get-Ps1EnvironmentNullCheck -Owner $owner `
								-Name $variableName)) {
						New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' ('Get-Environment stops when no environment matches, so $' + $variableName + ' is never null. Remove the null check and use it directly.') $itemCheck.Extent
					}
				}
			}

			foreach ($itemInterrupt in @(Get-Ps1EnvironmentInterruptCheck -Call $itemCommand)) {
				New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' 'Get-Environment stops execution when no environment matches. Remove the Test-PSFFunctionInterrupt check after the lookup; it cannot resume a stopped lookup.' $itemInterrupt.Extent
			}

			continue
		}

		$message = switch ($commandName) {
			'Get-BapEnvironment' {
				'Use Get-Environment instead of Get-BapEnvironment; the default shape needs no extra calls.'
			}
			'Get-UnifiedEnvironment' {
				$skipVersion = @($itemCommand.CommandElements | Where-Object {
						$_ -is [Management.Automation.Language.CommandParameterAst] -and
						'SkipVersionDetails'.StartsWith($_.ParameterName, [StringComparison]::OrdinalIgnoreCase)
					}).Count -gt 0

				if ($skipVersion) {
					'Use Get-Environment -Unified instead of Get-UnifiedEnvironment -SkipVersionDetails.'
				}
				else {
					'Use Get-Environment -Unified -VersionDetails instead of Get-UnifiedEnvironment; only callers that need provisioning data should pay for it.'
				}
			}
			default { $null }
		}

		if ($null -eq $message) { continue }

		New-Ps1Diagnostic $Path 'PSUseCentralEnvironmentLookup' $message $itemCommand.Extent
	}
}
