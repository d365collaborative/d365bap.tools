function Test-Ps1SupportsShouldProcess {
	param($Function)

	$paramBlock = $Function.Body.ParamBlock
	if ($null -eq $paramBlock) { return $false }

	foreach ($attribute in @($paramBlock.Attributes)) {
		if ($attribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($attribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.CmdletBindingAttribute]) { continue }

		foreach ($argument in @($attribute.NamedArguments)) {
			if ($argument.ArgumentName -ine 'SupportsShouldProcess') { continue }
			if ($null -eq $argument.Argument) { return $true }
			if ($argument.Argument -is [Management.Automation.Language.VariableExpressionAst] -and $argument.Argument.VariablePath.UserPath -ieq 'true') { return $true }
			if ($argument.Argument -is [Management.Automation.Language.ConstantExpressionAst] -and $argument.Argument.Value -eq $true) { return $true }
		}
	}

	$false
}

function Test-Ps1ShouldProcessCall {
	param($Node)

	$Node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
	$Node.Expression -is [Management.Automation.Language.VariableExpressionAst] -and
	$Node.Expression.VariablePath.UserPath -ieq 'PSCmdlet' -and
	$Node.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
	$Node.Member.Value -ieq 'ShouldProcess'
}

function Get-Ps1ShouldProcessOwner {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return $parent }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1ShouldProcessAssignment {
	param($Function, [string] $Name, $Call)

	$matches = @($Function.Body.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.AssignmentStatementAst] -and
				$Node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
				$Node.Left.VariablePath.UserPath -ieq $Name -and
				$Node.Extent.StartOffset -lt $Call.Extent.StartOffset -and
				(Get-Ps1ShouldProcessOwner -Node $Node) -eq $Function
			}, $true))

	if ($matches.Count -eq 0) { return $null }
	return ($matches | Sort-Object { $_.Extent.StartOffset } | Select-Object -Last 1)
}

function Get-Ps1ShouldProcessValue {
	param($Expression)

	$value = $Expression
	if ($value -is [Management.Automation.Language.CommandExpressionAst]) {
		$value = $value.Expression
	}
	elseif ($value -is [Management.Automation.Language.PipelineAst]) {
		$elements = @($value.PipelineElements)
		if ($elements.Count -eq 1 -and $elements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			$value = $elements[0].Expression
		}
	}
	return $value
}

function Test-Ps1ShouldProcessHumanTarget {
	param($Expression)

	$value = Get-Ps1ShouldProcessValue -Expression $Expression
	$tokens = @(
		foreach ($member in $value.FindAll({ param($Node) $Node -is [Management.Automation.Language.MemberExpressionAst] -and $Node.Member -is [Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
			$member.Member.Value
		}
		foreach ($variable in $value.FindAll({ param($Node) $Node -is [Management.Automation.Language.VariableExpressionAst] }, $true)) {
			$variable.VariablePath.UserPath
		}
	)

	@($tokens | Where-Object { $_ -match '(?i)(displayname|name|title|text|description)' }).Count -gt 0
}

function Test-Ps1ShouldProcessLabel {
	param($Expression)

	$value = Get-Ps1ShouldProcessValue -Expression $Expression

	if ($value -is [Management.Automation.Language.StringConstantExpressionAst]) {
		return -not [string]::IsNullOrWhiteSpace($value.Value)
	}

	if ($value -isnot [Management.Automation.Language.ExpandableStringExpressionAst]) { return $false }

	$literal = $value.Value
	foreach ($nested in @($value.NestedExpressions)) {
		$literal = $literal.Replace($nested.Extent.Text, '')
	}

	return $literal -match '[A-Za-z]{2,}'
}

function Get-Ps1ShouldProcessLength {
	param($Expression)

	$value = Get-Ps1ShouldProcessValue -Expression $Expression

	if ($value -is [Management.Automation.Language.StringConstantExpressionAst]) { return $value.Value.Length }

	if ($value -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
		$literal = $value.Value
		foreach ($nested in @($value.NestedExpressions)) {
			$literal = $literal.Replace($nested.Extent.Text, '')
		}
		return $literal.Length + 36 * @($value.NestedExpressions).Count
	}

	if ($value -is [Management.Automation.Language.VariableExpressionAst]) { return 36 }
	if ($value -is [Management.Automation.Language.MemberExpressionAst]) { return 36 }

	if ($value -is [Management.Automation.Language.ParenExpressionAst]) {
		return Get-Ps1ShouldProcessLength -Expression $value.Pipeline
	}

	if ($value -is [Management.Automation.Language.BinaryExpressionAst] -and "$($value.Operator)" -eq 'Plus') {
		return (Get-Ps1ShouldProcessLength -Expression $value.Left) + (Get-Ps1ShouldProcessLength -Expression $value.Right)
	}

	return 0
}

function Test-Ps1ShouldProcessAssignmentStatement {
	param($Statement, [string] $Name)

	$Statement -is [Management.Automation.Language.AssignmentStatementAst] -and
	$Statement.Left -is [Management.Automation.Language.VariableExpressionAst] -and
	$Statement.Left.VariablePath.UserPath -ieq $Name
}

function Get-Ps1ShouldProcessStructureMessage {
	param($Call)

	$if = $Call.Parent
	while ($null -ne $if) {
		if ($if -is [Management.Automation.Language.IfStatementAst]) { break }
		$if = $if.Parent
	}

	if ($null -eq $if) {
		return 'Wrap ShouldProcess in if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }.'
	}

	$condition = $if.Clauses[0].Item1
	if ($Call.Extent.StartOffset -lt $condition.Extent.StartOffset -or $Call.Extent.EndOffset -gt $condition.Extent.EndOffset) {
		return 'Use ShouldProcess as the condition of the if statement.'
	}

	$negated = $condition.Find({ param($Node) $Node -is [Management.Automation.Language.UnaryExpressionAst] -and "$($Node.TokenKind)" -eq 'Not' }, $false)
	if ($null -eq $negated -or $Call.Extent.StartOffset -lt $negated.Extent.StartOffset -or $Call.Extent.EndOffset -gt $negated.Extent.EndOffset) {
		return 'Negate ShouldProcess with -not in the if condition.'
	}

	$body = $if.Clauses[0].Item2
	if ($if.Clauses.Count -ne 1 -or $body.Statements.Count -ne 1 -or $body.Statements[0] -isnot [Management.Automation.Language.ReturnStatementAst]) {
		return 'Return immediately when ShouldProcess is not confirmed: { return }.'
	}

	$parent = $if.Parent
	if ($parent -isnot [Management.Automation.Language.StatementBlockAst] -and $parent -isnot [Management.Automation.Language.NamedBlockAst]) {
		return 'Place the ShouldProcess if statement directly after the assignments.'
	}

	$statements = @($parent.Statements)
	$index = [Array]::IndexOf($statements, $if)
	if ($index -lt 2) {
		return 'Place the $shouldAffected and $shouldLabel assignments directly before the ShouldProcess if statement.'
	}

	$affected = $statements[$index - 2]
	$label = $statements[$index - 1]

	if (-not (Test-Ps1ShouldProcessAssignmentStatement -Statement $affected -Name 'shouldAffected') -or
		-not (Test-Ps1ShouldProcessAssignmentStatement -Statement $label -Name 'shouldLabel')) {
		return 'Place the $shouldAffected and $shouldLabel assignments directly before the ShouldProcess if statement.'
	}

	if ($affected.Extent.EndLineNumber + 1 -ne $label.Extent.StartLineNumber) {
		return 'Keep the $shouldAffected and $shouldLabel assignments on consecutive lines.'
	}

	if ($label.Extent.EndLineNumber + 2 -ne $if.Extent.StartLineNumber) {
		return 'Keep exactly one blank line between $shouldLabel and the ShouldProcess if statement.'
	}

	$null
}

function New-Ps1ShouldProcessDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseShouldProcessConvention'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ShouldProcessDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($function in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		$declares = Test-Ps1SupportsShouldProcess -Function $function
		$calls = @($function.Body.FindAll({ param($Node) Test-Ps1ShouldProcessCall -Node $Node }, $true) |
			Where-Object { (Get-Ps1ShouldProcessOwner -Node $_) -eq $function })

		if ($declares -and $calls.Count -eq 0) {
			New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $function.Name.Extent `
				-Message 'Declares SupportsShouldProcess but never calls ShouldProcess. Add $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel).'
			continue
		}

		foreach ($call in $calls) {
			if (-not $declares) {
				New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent `
					-Message 'Calls ShouldProcess without declaring SupportsShouldProcess on CmdletBinding.'
				continue
			}

			$arguments = @($call.Arguments)
			if ($arguments.Count -ne 2) {
				New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent `
					-Message 'ShouldProcess must use the two-argument form: $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel).'
				continue
			}

			$first = $arguments[0]
			$second = $arguments[1]
			$firstOk = $first -is [Management.Automation.Language.VariableExpressionAst] -and $first.VariablePath.UserPath -ieq 'shouldAffected'
			$secondOk = $second -is [Management.Automation.Language.VariableExpressionAst] -and $second.VariablePath.UserPath -ieq 'shouldLabel'

			$affectedAssignment = $null
			$labelAssignment = $null

			if (-not $firstOk) {
				New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $first.Extent `
					-Message 'The first ShouldProcess argument must be the local variable $shouldAffected.'
			}
			else {
				$affectedAssignment = Get-Ps1ShouldProcessAssignment -Function $function -Name 'shouldAffected' -Call $call
				if ($null -eq $affectedAssignment) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent `
						-Message 'Assign $shouldAffected before calling ShouldProcess, using the target object, system or endpoint.'
				}
				elseif (-not (Test-Ps1ShouldProcessHumanTarget -Expression $affectedAssignment.Right)) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $affectedAssignment.Extent `
						-Message '$shouldAffected must include the target name, display name, title, text or description; an id alone is not human friendly.'
				}
				else {
					$length = Get-Ps1ShouldProcessLength -Expression $affectedAssignment.Right
					if ($length -gt 85) {
						New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $affectedAssignment.Extent `
							-Message ('$shouldAffected expands to ' + $length + ' characters (36 per variable); keep it to 85 or fewer.')
					}
				}
			}

			if (-not $secondOk) {
				New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $second.Extent `
					-Message 'The second ShouldProcess argument must be the local variable $shouldLabel.'
			}
			else {
				$labelAssignment = Get-Ps1ShouldProcessAssignment -Function $function -Name 'shouldLabel' -Call $call
				if ($null -eq $labelAssignment) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent `
						-Message 'Assign $shouldLabel before calling ShouldProcess with a human-readable action.'
				}
				elseif (-not (Test-Ps1ShouldProcessLabel -Expression $labelAssignment.Right)) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $labelAssignment.Extent `
						-Message '$shouldLabel must be a string literal that describes the action, not a bare id or a variable.'
				}
				else {
					$length = Get-Ps1ShouldProcessLength -Expression $labelAssignment.Right
					if ($length -gt 125) {
						New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $labelAssignment.Extent `
							-Message ('$shouldLabel expands to ' + $length + ' characters (36 per variable); keep it to 125 or fewer.')
					}
				}
			}

			if ($firstOk -and $secondOk -and $null -ne $affectedAssignment -and $null -ne $labelAssignment) {
				$structureMessage = Get-Ps1ShouldProcessStructureMessage -Call $call
				if ($null -ne $structureMessage) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent -Message $structureMessage
				}
			}
		}
	}
}
