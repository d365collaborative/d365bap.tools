function Test-Ps1SupportsShouldProcess {
	param($Function)

	$paramBlock = $Function.Body.ParamBlock
	if ($null -eq $paramBlock) { $false; return }

	foreach ($itemAttribute in @($paramBlock.Attributes)) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($itemAttribute.TypeName.GetReflectionAttributeType() -ne [Management.Automation.CmdletBindingAttribute]) { continue }

		foreach ($itemArgument in @($itemAttribute.NamedArguments)) {
			if ($itemArgument.ArgumentName -ine 'SupportsShouldProcess') { continue }
			if ($null -eq $itemArgument.Argument) { $true; return }
			if ($itemArgument.Argument -is [Management.Automation.Language.VariableExpressionAst] -and $itemArgument.Argument.VariablePath.UserPath -ieq 'true') { $true; return }
			if ($itemArgument.Argument -is [Management.Automation.Language.ConstantExpressionAst] -and $itemArgument.Argument.Value -eq $true) { $true; return }
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
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { $parent; return }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1ShouldProcessAssignment {
	param($Function, [string] $Name, $Call)

	$colMatches = @($Function.Body.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.AssignmentStatementAst] -and
				$Node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
				$Node.Left.VariablePath.UserPath -ieq $Name -and
				$Node.Extent.StartOffset -lt $Call.Extent.StartOffset -and
				(Get-Ps1ShouldProcessOwner -Node $Node) -eq $Function
			}, $true))

	if ($colMatches.Count -eq 0) { $null; return }
	($colMatches | Sort-Object { $_.Extent.StartOffset } | Select-Object -Last 1); return
}

function Get-Ps1ShouldProcessValue {
	param($Expression)

	$value = $Expression
	if ($value -is [Management.Automation.Language.CommandExpressionAst]) {
		$value = $value.Expression
	}
	elseif ($value -is [Management.Automation.Language.PipelineAst]) {
		$colElements = @($value.PipelineElements)
		if ($colElements.Count -eq 1 -and $colElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			$value = $colElements[0].Expression
		}
	}
	$value; return
}

function Test-Ps1ShouldProcessHumanTarget {
	param($Expression)

	$value = Get-Ps1ShouldProcessValue -Expression $Expression
	$colTokens = @(
		foreach ($itemMember in $value.FindAll({ param($Node) $Node -is [Management.Automation.Language.MemberExpressionAst] -and $Node.Member -is [Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
			$itemMember.Member.Value
		}
		foreach ($itemVariable in $value.FindAll({ param($Node) $Node -is [Management.Automation.Language.VariableExpressionAst] }, $true)) {
			$itemVariable.VariablePath.UserPath
		}
	)

	@($colTokens | Where-Object { $_ -match '(?i)(displayname|name|title|text|description)' }).Count -gt 0
}

function Test-Ps1ShouldProcessLabel {
	param($Expression)

	$value = Get-Ps1ShouldProcessValue -Expression $Expression

	if ($value -is [Management.Automation.Language.StringConstantExpressionAst]) {
		-not [string]::IsNullOrWhiteSpace($value.Value); return
	}

	if ($value -isnot [Management.Automation.Language.ExpandableStringExpressionAst]) { $false; return }

	$literal = $value.Value
	foreach ($itemNested in @($value.NestedExpressions)) {
		$literal = $literal.Replace($itemNested.Extent.Text, '')
	}

	$literal -match '[A-Za-z]{2,}'; return
}

function Get-Ps1ShouldProcessLength {
	param($Expression)

	$value = Get-Ps1ShouldProcessValue -Expression $Expression

	if ($value -is [Management.Automation.Language.StringConstantExpressionAst]) { $value.Value.Length; return }

	if ($value -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
		$literal = $value.Value
		foreach ($itemNested in @($value.NestedExpressions)) {
			$literal = $literal.Replace($itemNested.Extent.Text, '')
		}
		$literal.Length + 36 * @($value.NestedExpressions).Count; return
	}

	if ($value -is [Management.Automation.Language.VariableExpressionAst]) { 36; return }
	if ($value -is [Management.Automation.Language.MemberExpressionAst]) { 36; return }

	if ($value -is [Management.Automation.Language.ParenExpressionAst]) {
		Get-Ps1ShouldProcessLength -Expression $value.Pipeline; return
	}

	if ($value -is [Management.Automation.Language.BinaryExpressionAst] -and "$($value.Operator)" -eq 'Plus') {
		(Get-Ps1ShouldProcessLength -Expression $value.Left) + (Get-Ps1ShouldProcessLength -Expression $value.Right); return
	}

	0; return
}

function Test-Ps1ShouldProcessAssignmentStatement {
	param($Statement, [string] $Name)

	$Statement -is [Management.Automation.Language.AssignmentStatementAst] -and
	$Statement.Left -is [Management.Automation.Language.VariableExpressionAst] -and
	$Statement.Left.VariablePath.UserPath -ieq $Name
}

function Get-Ps1ShouldProcessGuardValue {
	param($Expression)
	$value = $Expression
	while ($null -ne $value) {
		if ($value -is [Management.Automation.Language.ParenExpressionAst]) { $value = $value.Pipeline; continue }
		if ($value -is [Management.Automation.Language.PipelineAst]) {
			if ($value.PipelineElements.Count -ne 1 -or $value.Background) { return }
			$value = $value.PipelineElements[0]; continue
		}
		if ($value -is [Management.Automation.Language.CommandExpressionAst]) {
			if ($value.Redirections.Count -gt 0) { return }
			$value = $value.Expression; continue
		}
		$value; return
	}
}

function Get-Ps1ShouldProcessStructureMessage {
	param($Call)

	$if = $Call.Parent
	while ($null -ne $if) {
		if ($if -is [Management.Automation.Language.IfStatementAst]) { break }
		$if = $if.Parent
	}

	if ($null -eq $if) {
		'Wrap ShouldProcess in if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }.'; return
	}

	$condition = $if.Clauses[0].Item1
	if ($Call.Extent.StartOffset -lt $condition.Extent.StartOffset -or $Call.Extent.EndOffset -gt $condition.Extent.EndOffset) {
		'Use ShouldProcess as the condition of the if statement.'; return
	}

	$value = Get-Ps1ShouldProcessGuardValue $condition
	if ($value -isnot [Management.Automation.Language.UnaryExpressionAst] -or "$($value.TokenKind)" -ne 'Not') {
		'Negate ShouldProcess with -not as the entire if condition.'; return
	}
	$value = Get-Ps1ShouldProcessGuardValue $value.Child
	if ($value -ne $Call) {
		'Use only -not $PSCmdlet.ShouldProcess(...) as the if condition.'; return
	}

	$body = $if.Clauses[0].Item2
	if ($if.Clauses.Count -ne 1 -or $null -ne $if.ElseClause) {
		'The ShouldProcess guard cannot have elseif or else branches.'; return
	}
	$colStatements = @($body.Statements)
	$valid = ($null -eq $body.Traps -or $body.Traps.Count -eq 0) -and $colStatements.Count -ge 1 -and $colStatements.Count -le 2 -and
	$colStatements[-1] -is [Management.Automation.Language.ReturnStatementAst] -and $null -eq $colStatements[-1].Pipeline
	if ($valid -and $colStatements.Count -eq 2) {
		$output = Get-Ps1ShouldProcessValue $colStatements[0]
		$valid = $output -is [Management.Automation.Language.VariableExpressionAst] -and
		$output.VariablePath.IsUnqualified -and -not $output.Splatted -and
		$colStatements[0] -is [Management.Automation.Language.PipelineAst] -and
		$colStatements[0].PipelineElements.Count -eq 1 -and -not $colStatements[0].Background -and
		$colStatements[0].PipelineElements[0].Redirections.Count -eq 0
	}
	if (-not $valid) {
		'Return immediately when ShouldProcess is not confirmed: use a bare return, optionally preceded by one local variable output.'; return
	}

	$parent = $if.Parent
	if ($parent -isnot [Management.Automation.Language.StatementBlockAst] -and $parent -isnot [Management.Automation.Language.NamedBlockAst]) {
		'Place the ShouldProcess if statement directly after the assignments.'; return
	}

	$colStatements = @($parent.Statements)
	$index = [Array]::IndexOf($colStatements, $if)
	if ($index -lt 2) {
		'Place the $shouldAffected and $shouldLabel assignments directly before the ShouldProcess if statement.'; return
	}

	$affected = $colStatements[$index - 2]
	$label = $colStatements[$index - 1]

	if (-not (Test-Ps1ShouldProcessAssignmentStatement -Statement $affected `
				-Name 'shouldAffected') -or
		-not (Test-Ps1ShouldProcessAssignmentStatement -Statement $label `
				-Name 'shouldLabel')) {
		'Place the $shouldAffected and $shouldLabel assignments directly before the ShouldProcess if statement.'; return
	}

	if ($affected.Extent.EndLineNumber + 1 -ne $label.Extent.StartLineNumber) {
		'Keep the $shouldAffected and $shouldLabel assignments on consecutive lines.'; return
	}

	if ($label.Extent.EndLineNumber + 2 -ne $if.Extent.StartLineNumber) {
		'Keep exactly one blank line between $shouldLabel and the ShouldProcess if statement.'; return
	}

	$null
}

function Get-Ps1ShouldProcessDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemFunction in @(Get-Ps1AstNode $Analysis FunctionDefinitionAst)) {
		$declares = Test-Ps1SupportsShouldProcess -Function $itemFunction
		$tmpCalls = @($itemFunction.Body.FindAll({ param($Node) Test-Ps1ShouldProcessCall -Node $Node }, $true) |
			Where-Object { (Get-Ps1ShouldProcessOwner -Node $_) -eq $itemFunction })

		if ($declares -and $tmpCalls.Count -eq 0) {
			New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'Declares SupportsShouldProcess but never calls ShouldProcess. Add $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel).' $itemFunction.Name.Extent
			continue
		}

		foreach ($itemCall in $tmpCalls) {
			if (-not $declares) {
				New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'Calls ShouldProcess without declaring SupportsShouldProcess on CmdletBinding.' $itemCall.Extent
				continue
			}

			$tmpArguments = @($itemCall.Arguments)
			if ($tmpArguments.Count -ne 2) {
				New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'ShouldProcess must use the two-argument form: $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel).' $itemCall.Extent
				continue
			}

			$first = $tmpArguments[0]
			$second = $tmpArguments[1]
			$firstOk = $first -is [Management.Automation.Language.VariableExpressionAst] -and $first.VariablePath.UserPath -ieq 'shouldAffected'
			$secondOk = $second -is [Management.Automation.Language.VariableExpressionAst] -and $second.VariablePath.UserPath -ieq 'shouldLabel'

			$affectedAssignment = $null
			$labelAssignment = $null

			if (-not $firstOk) {
				New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'The first ShouldProcess argument must be the local variable $shouldAffected.' $first.Extent
			}
			else {
				$affectedAssignment = Get-Ps1ShouldProcessAssignment -Function $itemFunction `
					-Name 'shouldAffected' `
					-Call $itemCall
				if ($null -eq $affectedAssignment) {
					New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'Assign $shouldAffected before calling ShouldProcess, using the target object, system or endpoint.' $itemCall.Extent
				}
				elseif (-not (Test-Ps1ShouldProcessHumanTarget -Expression $affectedAssignment.Right)) {
					New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' '$shouldAffected must include the target name, display name, title, text or description; an id alone is not human friendly.' $affectedAssignment.Extent
				}
				else {
					$length = Get-Ps1ShouldProcessLength -Expression $affectedAssignment.Right
					if ($length -gt 85) {
						New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' ('$shouldAffected expands to ' + $length + ' characters (36 per variable); keep it to 85 or fewer.') $affectedAssignment.Extent
					}
				}
			}

			if (-not $secondOk) {
				New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'The second ShouldProcess argument must be the local variable $shouldLabel.' $second.Extent
			}
			else {
				$labelAssignment = Get-Ps1ShouldProcessAssignment -Function $itemFunction `
					-Name 'shouldLabel' `
					-Call $itemCall
				if ($null -eq $labelAssignment) {
					New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' 'Assign $shouldLabel before calling ShouldProcess with a human-readable action.' $itemCall.Extent
				}
				elseif (-not (Test-Ps1ShouldProcessLabel -Expression $labelAssignment.Right)) {
					New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' '$shouldLabel must be a string literal that describes the action, not a bare id or a variable.' $labelAssignment.Extent
				}
				else {
					$length = Get-Ps1ShouldProcessLength -Expression $labelAssignment.Right
					if ($length -gt 125) {
						New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' ('$shouldLabel expands to ' + $length + ' characters (36 per variable); keep it to 125 or fewer.') $labelAssignment.Extent
					}
				}
			}

			if ($firstOk -and $secondOk -and $null -ne $affectedAssignment -and $null -ne $labelAssignment) {
				$structureMessage = Get-Ps1ShouldProcessStructureMessage -Call $itemCall
				if ($null -ne $structureMessage) {
					New-Ps1Diagnostic $Path 'PSUseShouldProcessConvention' $structureMessage $itemCall.Extent
				}
			}
		}
	}
}
