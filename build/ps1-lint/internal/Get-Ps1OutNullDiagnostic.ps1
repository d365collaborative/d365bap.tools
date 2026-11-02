function Test-Ps1OutNullShadowed {
	param($Analysis)

	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		if ($itemFunction.Name -eq 'Out-Null') {
			$true
			return
		}
	}

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine 'Set-Alias') { continue }
		foreach ($itemElement in $itemCommand.CommandElements) {
			if ($itemElement -is [Management.Automation.Language.StringConstantExpressionAst] -and $itemElement.Value -eq 'Out-Null') {
				$true
				return
			}
		}
	}

	$false
}

function New-Ps1OutNullDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidOutNull'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1NullAssignmentMessage {
	param($Assignment)

	if ($Assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { $null; return }
	if ($Assignment.Left.VariablePath.UserPath -ine 'null') { $null; return }

	$right = $Assignment.Right
	if ($right -is [Management.Automation.Language.PipelineAst]) {
		$target = @($right.PipelineElements)[-1]
	}
	elseif ($right -is [Management.Automation.Language.CommandExpressionAst]) {
		$target = $right
	}
	else { $null; return }

	$commandName = $null
	$hasCommand = $false
	if ($target -is [Management.Automation.Language.CommandAst]) {
		$hasCommand = $true
		$commandName = $target.GetCommandName()
	}
	else {
		$hasCommand = $null -ne $target.Find({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $false)
		if ($target -is [Management.Automation.Language.CommandExpressionAst] -and
			$target.Expression -is [Management.Automation.Language.ParenExpressionAst]) {
			$colInner = @($target.Expression.Pipeline.PipelineElements)
			if ($colInner.Count -eq 1 -and $colInner[0] -is [Management.Automation.Language.CommandAst]) {
				$commandName = $colInner[0].GetCommandName()
			}
		}
	}

	$hasInvocation = $null -ne $target.Find({ param($Node) $Node -is [Management.Automation.Language.InvokeMemberExpressionAst] }, $false)
	if (-not $hasCommand -and -not $hasInvocation) { $null; return }

	if (-not [string]::IsNullOrEmpty($commandName)) {
		"Do not discard output with a `$null` assignment. Redirect it to `$null` instead: $commandName ... > `$null."
		return
	}

	'Do not discard output with a $null assignment. Redirect it to $null instead: <expression> > $null.'
}

function Get-Ps1OutNullDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isModuleFile = $normalized -match '/d365bap\.tools/(functions|internal)/'
	$isLintTooling = $normalized -match '/build/ps1-lint/'
	if (-not $isModuleFile -and -not $isLintTooling) { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	if (-not (Test-Ps1OutNullShadowed -Analysis $Analysis)) {
		foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
			$commandName = $itemCommand.GetCommandName()
			if ($null -eq $commandName) { continue }
			if (($commandName -split '\\')[-1] -ine 'Out-Null') { continue }

			New-Ps1OutNullDiagnostic -Path $Path `
				-Extent $itemCommand.Extent `
				-Message 'Do not discard output with Out-Null. Redirect it to $null instead: <expression> > $null.'
		}
	}

	foreach ($itemAssignment in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
		$message = Get-Ps1NullAssignmentMessage -Assignment $itemAssignment
		if ($null -eq $message) { continue }

		New-Ps1OutNullDiagnostic -Path $Path `
			-Extent $itemAssignment.Extent `
			-Message $message
	}
}
