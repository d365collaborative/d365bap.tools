$script:Ps1EnvironmentLookupExemptions = @(
	'Get-BapEnvironment.ps1'
	'Get-UnifiedEnvironment.ps1'
	'Get-Environment.ps1'
)

function Get-Ps1EnvironmentOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return $parent }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1EnvironmentAssignment {
	param($Call)

	$node = $Call.Parent
	while ($null -ne $node) {
		if ($node -is [Management.Automation.Language.AssignmentStatementAst]) { return $node }
		if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { return $null }
		$node = $node.Parent
	}
	$null
}

function Test-Ps1EnvironmentTryAncestor {
	param($Call)

	$node = $Call.Parent
	while ($null -ne $node) {
		if ($node -is [Management.Automation.Language.TryStatementAst]) { return $true }
		if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { return $false }
		$node = $node.Parent
	}
	$false
}

function Get-Ps1EnvironmentNullCheck {
	param($Owner, [string] $Name)

	foreach ($node in $Owner.Body.FindAll({ param($n) $n -is [Management.Automation.Language.BinaryExpressionAst] -and "$($n.Operator)" -in @('Ieq', 'Ine') }, $true)) {
		if ((Get-Ps1EnvironmentOwnerFunction -Node $node) -ne $Owner) { continue }

		$left = $node.Left
		$right = $node.Right
		$isNullLeft = $left -is [Management.Automation.Language.VariableExpressionAst] -and $left.VariablePath.UserPath -ieq 'null'
		$isNullRight = $right -is [Management.Automation.Language.VariableExpressionAst] -and $right.VariablePath.UserPath -ieq 'null'
		$isNameLeft = $left -is [Management.Automation.Language.VariableExpressionAst] -and $left.VariablePath.UserPath -ieq $Name
		$isNameRight = $right -is [Management.Automation.Language.VariableExpressionAst] -and $right.VariablePath.UserPath -ieq $Name

		if (($isNullLeft -and $isNameRight) -or ($isNullRight -and $isNameLeft)) { $node }
	}
}

function New-Ps1EnvironmentLookupDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseCentralEnvironmentLookup'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1EnvironmentLookupDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }

	$fileName = [IO.Path]::GetFileName($Path)
	if ($fileName -like '*Tests.ps1') { return }
	if ($fileName -in $script:Ps1EnvironmentLookupExemptions) { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }

		$commandName = ($commandName -split '\\')[-1]

		if ($commandName -eq 'Get-Environment') {
			if (Test-Ps1EnvironmentTryAncestor -Call $itemCommand) {
				New-Ps1EnvironmentLookupDiagnostic -Path $Path -Extent $itemCommand.Extent `
					-Message 'Do not wrap Get-Environment in try/catch. It stops execution when no environment matches; let that surface.'
			}

			$assignment = Get-Ps1EnvironmentAssignment -Call $itemCommand
			$variableName = $null

			if ($null -eq $assignment) {
				New-Ps1EnvironmentLookupDiagnostic -Path $Path -Extent $itemCommand.Extent `
					-Message 'Assign Get-Environment to a local variable named $envObj so later code can use the environment directly.'
			}
			elseif ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) {
				New-Ps1EnvironmentLookupDiagnostic -Path $Path -Extent $assignment.Extent `
					-Message 'Assign Get-Environment to a local variable named $envObj so later code can use the environment directly.'
			}
			else {
				$variableName = $assignment.Left.VariablePath.UserPath
				if ($variableName -notmatch '^envObj') {
					New-Ps1EnvironmentLookupDiagnostic -Path $Path -Extent $assignment.Left.Extent `
						-Message ('Assign Get-Environment to a local variable named $envObj (found $' + $variableName + ').')
				}
			}

			if ($null -ne $variableName) {
				$owner = Get-Ps1EnvironmentOwnerFunction -Node $itemCommand
				if ($null -ne $owner) {
					foreach ($check in @(Get-Ps1EnvironmentNullCheck -Owner $owner -Name $variableName)) {
						New-Ps1EnvironmentLookupDiagnostic -Path $Path -Extent $check.Extent `
							-Message ('Get-Environment stops when no environment matches, so $' + $variableName + ' is never null. Remove the null check and use it directly.')
					}
				}
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

		New-Ps1EnvironmentLookupDiagnostic -Path $Path -Extent $itemCommand.Extent -Message $message
	}
}
