$script:Ps1VariableAutomaticNames = @(
	'_'
	'PSItem'
	'PSCmdlet'
	'PSBoundParameters'
	'args'
	'input'
	'error'
	'true'
	'false'
	'null'
	'MyInvocation'
	'PSCommandPath'
	'PSScriptRoot'
	'PWD'
	'HOME'
	'LASTEXITCODE'
	'Matches'
	'NestedPromptLevel'
	'ExecutionContext'
	'StackTrace'
	'PSVersionTable'
	'IsWindows'
	'IsLinux'
	'IsMacOS'
	'IsCoreCLR'
	'OutputEncoding'
	'?'
	'^'
	'$'
)

function Get-Ps1VariableOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return $parent }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1VariableIterationScope {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.ForEachStatementAst] -or
			$parent -is [Management.Automation.Language.ForStatementAst] -or
			$parent -is [Management.Automation.Language.WhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoWhileStatementAst] -or
			$parent -is [Management.Automation.Language.DoUntilStatementAst]) {
			return $parent
		}
		if ($parent -is [Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -eq 'ForEach-Object') { return $parent }
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return $null }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1VariableValue {
	param($Right)

	$value = $Right
	if ($value -is [Management.Automation.Language.CommandExpressionAst]) { $value = $value.Expression }
	elseif ($value -is [Management.Automation.Language.PipelineAst] -and
		$value.PipelineElements.Count -eq 1 -and
		$value.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
		$value = $value.PipelineElements[0].Expression
	}
	return $value
}

function Test-Ps1VariableCollectionValue {
	param($Right)

	$value = Get-Ps1VariableValue -Right $Right

	if ($value -is [Management.Automation.Language.ArrayExpressionAst] -or
		$value -is [Management.Automation.Language.ArrayLiteralAst] -or
		$value -is [Management.Automation.Language.ForEachStatementAst]) {
		return $true
	}

	if ($value -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
		$value.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
		$value.Member.Value -ieq 'new' -and
		$value.Expression.Extent.Text -match 'Collections') {
		return $true
	}

	$false
}

function Test-Ps1VariableHashtableValue {
	param($Right)

	$value = Get-Ps1VariableValue -Right $Right

	if ($value -is [Management.Automation.Language.HashtableAst]) { return $true }

	if ($value -is [Management.Automation.Language.ConvertExpressionAst]) {
		$typeName = $value.Type.TypeName.Name

		if ($typeName -match 'hashtable|ordered|dictionary') { return $true }
		if ($value.Child -is [Management.Automation.Language.HashtableAst] -and $typeName -notmatch 'pscustomobject') { return $true }
	}

	if ($value -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
		$value.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
		$value.Member.Value -ieq 'new' -and
		$value.Expression.Extent.Text -match 'hashtable|ordered|dictionary') {
		return $true
	}

	if ($value -isnot [Management.Automation.Language.PipelineAst]) { return $false }

	$colElements = @($value.PipelineElements)
	if ($colElements.Count -eq 0) { return $false }

	$last = $colElements[-1]
	if ($last -isnot [Management.Automation.Language.CommandAst] -or $last.GetCommandName() -ne 'New-Object') { return $false }

	return @($last.CommandElements | Where-Object {
			$_ -is [Management.Automation.Language.StringConstantExpressionAst] -and
			$_.Value -match 'hashtable|ordered|dictionary'
		}).Count -gt 0
}

function Test-Ps1VariableObjectValue {
	param($Right)

	$value = Get-Ps1VariableValue -Right $Right

	if ($value -is [Management.Automation.Language.ConvertExpressionAst] -and $value.Type.TypeName.Name -ieq 'pscustomobject') { return $true }

	if ($value -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
		$value.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
		$value.Member.Value -ieq 'new' -and
		$value.Expression.Extent.Text -match 'pscustomobject') {
		return $true
	}

	if ($value -isnot [Management.Automation.Language.PipelineAst]) { return $false }

	$colElements = @($value.PipelineElements)
	if ($colElements.Count -eq 0) { return $false }

	$last = $colElements[-1]
	if ($last -isnot [Management.Automation.Language.CommandAst]) { return $false }

	$commandName = $last.GetCommandName()
	if ($commandName -eq 'New-Object') { return $true }

	if ($commandName -eq 'Select-Object') {
		return @($last.CommandElements | Where-Object {
				$_ -is [Management.Automation.Language.CommandParameterAst] -and
				'First'.StartsWith($_.ParameterName, [StringComparison]::OrdinalIgnoreCase)
			}).Count -gt 0
	}

	return $false
}

function Test-Ps1VariableGetEnvironmentValue {
	param($Right)

	@($Right.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] -and ($Node.GetCommandName() -split '\\')[-1] -eq 'Get-Environment' }, $true)).Count -gt 0
}

function New-Ps1VariableNamingDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseVariableNamingConvention'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1VariableNamingDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isModuleFile = $normalized -match '/d365bap\.tools/(functions|internal)/'
	$isBuildScript = $normalized -match '/build/'
	if (-not $isModuleFile -and -not $isBuildScript) { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$colParameterNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	foreach ($itemParameter in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ParameterAst] }, $true)) {
		$null = $colParameterNames.Add($itemParameter.Name.VariablePath.UserPath)
	}

	$hashForEachSources = @{}
	foreach ($itemForEach in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
		$owner = Get-Ps1VariableOwnerFunction -Node $itemForEach
		if ($null -eq $owner) { continue }
		$condition = Get-Ps1VariableValue -Right $itemForEach.Condition
		if ($condition -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
		if (-not $hashForEachSources.ContainsKey($owner)) {
			$hashForEachSources[$owner] = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
		}
		$null = $hashForEachSources[$owner].Add($condition.VariablePath.UserPath)
	}

	foreach ($itemForEach in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ForEachStatementAst] }, $true)) {
		$owner = Get-Ps1VariableOwnerFunction -Node $itemForEach
		if ($null -eq $owner) { continue }

		$name = $itemForEach.Variable.VariablePath.UserPath
		if ($script:Ps1VariableAutomaticNames -contains $name) { continue }
		if ($name -match '^item') { continue }

		New-Ps1VariableNamingDiagnostic -Path $Path -Extent $itemForEach.Variable.Extent `
			-Message "The foreach item variable $name should be prefixed with 'item'."
	}

	foreach ($itemAssignment in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
		if ($itemAssignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }

		$owner = Get-Ps1VariableOwnerFunction -Node $itemAssignment
		if ($null -eq $owner) { continue }

		$name = $itemAssignment.Left.VariablePath.UserPath
		if ($script:Ps1VariableAutomaticNames -contains $name) { continue }
		if ($name.Contains(':')) { continue }
		if ($colParameterNames.Contains($name)) { continue }

		$inLoop = $null -ne (Get-Ps1VariableIterationScope -Node $itemAssignment)
		$isHashtable = Test-Ps1VariableHashtableValue -Right $itemAssignment.Right
		$isCollection = $false

		if (-not $isHashtable) {
			$isCollection = Test-Ps1VariableCollectionValue -Right $itemAssignment.Right
			if (-not $isCollection -and $null -ne $hashForEachSources[$owner] -and $hashForEachSources[$owner].Contains($name)) {
				$isCollection = $true
			}
		}

		if (-not $isHashtable -and -not $isCollection) {
			if (Test-Ps1VariableGetEnvironmentValue -Right $itemAssignment.Right) { continue }
			if (-not (Test-Ps1VariableObjectValue -Right $itemAssignment.Right)) { continue }
		}

		$prefix = if ($inLoop) { 'tmp' } elseif ($isHashtable) { 'hash' } elseif ($isCollection) { 'col' } else { 'obj' }

		if ($name -match "^$prefix") { continue }

		$scopeMessage = if ($inLoop) {
			"Variable $name is declared inside a loop; prefix it with 'tmp'."
		}
		elseif ($isHashtable) {
			"Variable $name holds a hashtable; prefix it with 'hash'."
		}
		elseif ($isCollection) {
			"Variable $name holds a collection; prefix it with 'col'."
		}
		else {
			"Variable $name holds a single object at the function root; prefix it with 'obj'."
		}

		New-Ps1VariableNamingDiagnostic -Path $Path -Extent $itemAssignment.Left.Extent -Message $scopeMessage
	}
}
