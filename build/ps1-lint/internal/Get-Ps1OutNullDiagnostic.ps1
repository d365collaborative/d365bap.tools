function Test-Ps1OutNullShadowed {
	param([hashtable] $Analysis)

	foreach ($itemFunction in @(Get-Ps1AstNode $Analysis FunctionDefinitionAst)) {
		if ($itemFunction.Name -eq 'Out-Null') {
			$true
			return
		}
	}

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
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

function Get-Ps1OutNullDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleOrLintTooling')) { return }

	$shadowed = Test-Ps1OutNullShadowed -Analysis $Analysis
	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if ($commandName -ine 'Microsoft.PowerShell.Core\Out-Null' -and ($commandName -ine 'Out-Null' -or $shadowed)) { continue }

		New-Ps1Diagnostic $Path 'PSAvoidOutNull' 'Do not discard output with Out-Null. Redirect it to $null instead: <expression> > $null.' $itemCommand.Extent
	}
	foreach ($itemCast in @(Get-Ps1AstNode $Analysis ConvertExpressionAst)) {
		if ($itemCast.Type.TypeName.FullName -in @('void', 'System.Void')) {
			New-Ps1Diagnostic $Path 'PSAvoidOutNull' 'Do not discard output with a void cast. Redirect it to $null instead: <expression> > $null.' $itemCast.Extent
		}
	}

	foreach ($itemAssignment in @(Get-Ps1AstNode $Analysis AssignmentStatementAst)) {
		$message = Get-Ps1NullAssignmentMessage -Assignment $itemAssignment
		if ($null -eq $message) { continue }

		New-Ps1Diagnostic $Path 'PSAvoidOutNull' $message $itemAssignment.Extent
	}
}

function Test-Ps1KeywordStatement {
	param($Node)

	$Node -is [Management.Automation.Language.IfStatementAst] -or
	$Node -is [Management.Automation.Language.SwitchStatementAst] -or
	$Node -is [Management.Automation.Language.ForEachStatementAst] -or
	$Node -is [Management.Automation.Language.ForStatementAst] -or
	$Node -is [Management.Automation.Language.WhileStatementAst] -or
	$Node -is [Management.Automation.Language.DoWhileStatementAst] -or
	$Node -is [Management.Automation.Language.TryStatementAst]
}

function Get-Ps1NullAssignmentMessage {
	param($Assignment)

	if ($Assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { $null; return }
	if ($Assignment.Left.VariablePath.UserPath -ine 'null') { $null; return }

	if (Test-Ps1KeywordStatement -Node $Assignment.Right) {
		'Do not use a `$null` assignment. Wrap the statement in a subexpression and redirect it to `$null` instead: $(<statement>) > `$null.'
		return
	}

	$colCommand = @($Assignment.Right.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $false))
	$commandName = $null
	if ($colCommand.Count -gt 0) { $commandName = $colCommand[0].GetCommandName() }

	if (-not [string]::IsNullOrEmpty($commandName)) {
		"Do not discard output with a `$null` assignment. Redirect it to `$null` instead: $commandName ... > `$null."
		return
	}

	'Do not discard a value with a `$null` assignment. Redirect it to `$null` instead: <expression> > `$null.'
}
