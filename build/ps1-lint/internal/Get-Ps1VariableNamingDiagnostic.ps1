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

function Get-Ps1OutputTypeKind {
	param([string[]] $Types)

	$colKinds = [System.Collections.Generic.List[string]]::new()
	foreach ($itemType in @($Types)) {
		$typeName = "$itemType".Trim("'", '"')
		if ([string]::IsNullOrWhiteSpace($typeName)) { continue }

		if ($typeName -match '(?i)^(system\.)?void$') { continue }
		if ($typeName -match '(?i)^(system\.)?(string|char|bool|boolean|byte|sbyte|int16|int32|int64|uint16|uint32|uint64|single|double|decimal|datetime|datetimeoffset|timespan|guid|version)$') {
			$colKinds.Add('scalar')
			continue
		}
		if ($typeName -match '(?i)(hashtable|dictionary|ordereddictionary)') {
			$colKinds.Add('hash')
			continue
		}
		if ($typeName -match '(?i)(\[\]|array|collection|list|ienumerable|icollection|hashset|queue|stack)') {
			$colKinds.Add('col')
			continue
		}
		if ($typeName -match '(?i)(pscustomobject|psobject)') {
			$colKinds.Add('obj')
			continue
		}
		if ($typeName -match '(?i)^(system\.)?object$') { continue }

		$colKinds.Add('obj')
	}

	$colUnique = @($colKinds | Sort-Object -Unique)
	if ($colUnique.Count -ne 1) { return }
	if ($colUnique[0] -eq 'scalar') { return }
	$colUnique[0]
}

function Get-Ps1FunctionOutputType {
	param($Function)

	$paramBlock = $Function.Body.ParamBlock
	if ($null -eq $paramBlock) { return }

	$colTypes = [System.Collections.Generic.List[string]]::new()
	foreach ($itemAttribute in @($paramBlock.Attributes)) {
		if ($itemAttribute -isnot [Management.Automation.Language.AttributeAst]) { continue }
		if ($itemAttribute.TypeName.Name -ne 'OutputType') { continue }

		foreach ($itemArgument in @($itemAttribute.PositionalArguments)) {
			if ($itemArgument -is [Management.Automation.Language.StringConstantExpressionAst]) {
				$colTypes.Add($itemArgument.Value)
			}
			elseif ($itemArgument -is [Management.Automation.Language.TypeExpressionAst]) {
				$colTypes.Add($itemArgument.TypeName.Name)
			}
			elseif ($itemArgument -is [Management.Automation.Language.TypeConstraintAst]) {
				$colTypes.Add($itemArgument.TypeName.Name)
			}
		}
	}

	$colTypes.ToArray()
}

function Get-Ps1OutputTypeMap {
	param([string] $Path, [hashtable] $Worker)

	if ($null -eq $Worker) { $Worker = Get-Ps1AnalysisWorker }

	$moduleRoot = Get-Ps1ModuleRoot -Path $Path
	if ($null -eq $moduleRoot) { @{}; return }

	(Get-Ps1RepositoryIndex -ModuleRoot $moduleRoot -Worker $Worker).OutputTypes
}

function Get-Ps1VariableOutputTypeKind {
	param($Right, [hashtable] $OutputTypes)

	if ($null -eq $OutputTypes -or $OutputTypes.Count -eq 0) { return }

	$value = Get-Ps1VariableValue -Right $Right
	$command = $null
	if ($value -is [Management.Automation.Language.PipelineAst]) {
		$colElements = @($value.PipelineElements)
		if ($colElements.Count -eq 0) { return }
		if ($colElements[0] -is [Management.Automation.Language.CommandAst]) { $command = $colElements[0] }
	}
	elseif ($value -is [Management.Automation.Language.CommandAst]) {
		$command = $value
	}
	if ($null -eq $command) { return }

	$commandName = $command.GetCommandName()
	if ($null -eq $commandName) { return }
	$commandName = ($commandName -split '\\')[-1]
	if (-not $OutputTypes.ContainsKey($commandName)) { return }
	$OutputTypes[$commandName]
}

function Get-Ps1VariableOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { $parent; return }
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
			$parent; return
		}
		if ($parent -is [Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -eq 'ForEach-Object') { $parent; return }
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return }
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
	$value; return
}

function Test-Ps1VariableCollectionValue {
	param($Right)

	$value = Get-Ps1VariableValue -Right $Right

	if ($value -is [Management.Automation.Language.ArrayExpressionAst] -or
		$value -is [Management.Automation.Language.ArrayLiteralAst] -or
		$value -is [Management.Automation.Language.ForEachStatementAst]) {
		$true; return
	}

	if ($value -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
		$value.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
		$value.Member.Value -ieq 'new' -and
		$value.Expression.Extent.Text -match 'Collections') {
		$true; return
	}

	$false
}

function Test-Ps1VariableHashtableValue {
	param($Right)

	$value = Get-Ps1VariableValue -Right $Right

	if ($value -is [Management.Automation.Language.HashtableAst]) { $true; return }

	if ($value -is [Management.Automation.Language.ConvertExpressionAst]) {
		$typeName = $value.Type.TypeName.Name

		if ($typeName -match 'hashtable|ordered|dictionary') { $true; return }
		if ($value.Child -is [Management.Automation.Language.HashtableAst] -and $typeName -notmatch 'pscustomobject') { $true; return }
	}

	if ($value -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
		$value.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
		$value.Member.Value -ieq 'new' -and
		$value.Expression.Extent.Text -match 'hashtable|ordered|dictionary') {
		$true; return
	}

	if ($value -isnot [Management.Automation.Language.PipelineAst]) { $false; return }

	$colElements = @($value.PipelineElements)
	if ($colElements.Count -eq 0) { $false; return }

	$last = $colElements[-1]
	if ($last -isnot [Management.Automation.Language.CommandAst] -or $last.GetCommandName() -ne 'New-Object') { $false; return }

	@($last.CommandElements | Where-Object {
			$_ -is [Management.Automation.Language.StringConstantExpressionAst] -and
			$_.Value -match 'hashtable|ordered|dictionary'
		}).Count -gt 0
}

function Test-Ps1VariableObjectValue {
	param($Right)

	$value = Get-Ps1VariableValue -Right $Right

	if ($value -is [Management.Automation.Language.ConvertExpressionAst] -and $value.Type.TypeName.Name -ieq 'pscustomobject') { $true; return }

	if ($value -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
		$value.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and
		$value.Member.Value -ieq 'new' -and
		$value.Expression.Extent.Text -match 'pscustomobject') {
		$true; return
	}

	if ($value -isnot [Management.Automation.Language.PipelineAst]) { $false; return }

	$colElements = @($value.PipelineElements)
	if ($colElements.Count -eq 0) { $false; return }

	$last = $colElements[-1]
	if ($last -isnot [Management.Automation.Language.CommandAst]) { $false; return }

	$commandName = $last.GetCommandName()
	if ($commandName -eq 'New-Object') { $true; return }

	if ($commandName -eq 'Select-Object') {
		$colElements = @($last.CommandElements)
		for ($index = 0; $index -lt $colElements.Count; $index++) {
			$tmpElement = $colElements[$index]
			if ($tmpElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if (-not 'First'.StartsWith($tmpElement.ParameterName, [StringComparison]::OrdinalIgnoreCase)) { continue }

			$tmpArgument = $null
			if ($null -ne $tmpElement.Argument) { $tmpArgument = $tmpElement.Argument }
			elseif ($index + 1 -lt $colElements.Count) { $tmpArgument = $colElements[$index + 1] }

			if ($tmpArgument -is [Management.Automation.Language.ConstantExpressionAst] -and "$($tmpArgument.Value)" -eq '1') { $true; return }
			$false; return
		}

		$false; return
	}

	$false; return
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
	param([hashtable] $Analysis, [hashtable] $Worker)
	$Path = $Analysis.Path
	if ($null -eq $Worker) { $Worker = Get-Ps1AnalysisWorker }

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

	$hashOutputTypes = if ($isModuleFile) { Get-Ps1OutputTypeMap -Path $Path -Worker $Worker } else { @{} }

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

		$isObject = $false
		if (-not $isHashtable -and -not $isCollection) {
			if (Test-Ps1VariableGetEnvironmentValue -Right $itemAssignment.Right) { continue }

			$isObject = Test-Ps1VariableObjectValue -Right $itemAssignment.Right
			if (-not $isObject) {
				$outputKind = Get-Ps1VariableOutputTypeKind -Right $itemAssignment.Right -OutputTypes $hashOutputTypes
				if ($outputKind -eq 'hash') { $isHashtable = $true }
				elseif ($outputKind -eq 'col') { $isCollection = $true }
				elseif ($outputKind -eq 'obj') { $isObject = $true }
				else { continue }
			}
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
