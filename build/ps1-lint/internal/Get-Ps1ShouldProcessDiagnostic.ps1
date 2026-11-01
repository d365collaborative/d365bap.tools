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

function Test-Ps1ShouldProcessHumanTarget {
	param($Expression)

	$tokens = @(
		foreach ($member in $Expression.FindAll({ param($Node) $Node -is [Management.Automation.Language.MemberExpressionAst] -and $Node.Member -is [Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
			$member.Member.Value
		}
		foreach ($variable in $Expression.FindAll({ param($Node) $Node -is [Management.Automation.Language.VariableExpressionAst] }, $true)) {
			$variable.VariablePath.UserPath
		}
	)

	@($tokens | Where-Object { $_ -match '(?i)(displayname|name|title|text|description)' }).Count -gt 0
}

function Test-Ps1ShouldProcessLabel {
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
			if ($first -isnot [Management.Automation.Language.VariableExpressionAst] -or $first.VariablePath.UserPath -ine 'shouldAffected') {
				New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $first.Extent `
					-Message 'The first ShouldProcess argument must be the local variable $shouldAffected.'
			}
			else {
				$assignment = Get-Ps1ShouldProcessAssignment -Function $function -Name 'shouldAffected' -Call $call
				if ($null -eq $assignment) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent `
						-Message 'Assign $shouldAffected before calling ShouldProcess, using the target object, system or endpoint.'
				}
				elseif (-not (Test-Ps1ShouldProcessHumanTarget -Expression $assignment.Right)) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $assignment.Extent `
						-Message '$shouldAffected must include the target name, display name, title, text or description; an id alone is not human friendly.'
				}
			}

			$second = $arguments[1]
			if ($second -isnot [Management.Automation.Language.VariableExpressionAst] -or $second.VariablePath.UserPath -ine 'shouldLabel') {
				New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $second.Extent `
					-Message 'The second ShouldProcess argument must be the local variable $shouldLabel.'
			}
			else {
				$assignment = Get-Ps1ShouldProcessAssignment -Function $function -Name 'shouldLabel' -Call $call
				if ($null -eq $assignment) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $call.Extent `
						-Message 'Assign $shouldLabel before calling ShouldProcess with a human-readable action.'
				}
				elseif (-not (Test-Ps1ShouldProcessLabel -Expression $assignment.Right)) {
					New-Ps1ShouldProcessDiagnostic -Path $Path -Extent $assignment.Extent `
						-Message '$shouldLabel must be a string literal that describes the action, not a bare id or a variable.'
				}
			}
		}
	}
}
