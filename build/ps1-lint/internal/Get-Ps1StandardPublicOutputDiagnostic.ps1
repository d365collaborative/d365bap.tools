. "$PSScriptRoot/Get-Ps1OutputModel.ps1"

$script:Ps1PublicOutputWorksheetExemption = @{
	'Get-UdeConnection' = 'UdeConnection'
}

function Get-Ps1OutputTableFormatType {
	param([string] $TableDirectory)

	if ($null -ne $script:Ps1TableFormatTypes -and $script:Ps1TableFormatTypes.Directory -eq $TableDirectory) {
		$script:Ps1TableFormatTypes.Types; return
	}
	$hashTypes = @{}
	if (Test-Path -LiteralPath $TableDirectory `
			-PathType Container) {
		foreach ($itemFile in Get-ChildItem -LiteralPath $TableDirectory `
				-Filter '*.ps1xml' `
				-File) {
			try {
				[xml] $document = Get-Content -LiteralPath $itemFile.FullName `
					-Raw
			}
			catch { continue }
			foreach ($itemView in @($document.Configuration.ViewDefinitions.View)) {
				if ($null -eq $itemView.TableControl) { continue }
				foreach ($itemTypeName in @($itemView.ViewSelectedBy.TypeName)) {
					if ($null -ne $itemTypeName -and $itemTypeName -ne '') { $hashTypes[[string]$itemTypeName] = $true }
				}
			}
		}
	}
	$script:Ps1TableFormatTypes = @{ Directory = $TableDirectory; Types = $hashTypes }
	$hashTypes
}

function Get-Ps1PublicOutputWorksheetName {
	param($Function)

	if ($script:Ps1PublicOutputWorksheetExemption.ContainsKey($Function.Name)) {
		$script:Ps1PublicOutputWorksheetExemption[$Function.Name]; return
	}
	$Function.Name
}

function Get-Ps1OutputExcelConditionVariable {
	param($Condition)

	$value = $Condition
	if ($value -is [Management.Automation.Language.PipelineAst] -and $value.PipelineElements.Count -eq 1) {
		$value = $value.PipelineElements[0]
	}
	if ($value -is [Management.Automation.Language.CommandExpressionAst]) {
		$value = $value.Expression
	}
	$value
}

function Get-Ps1OutputExcelWorksheetParameter {
	param($Command)

	$hashResult = @{ Found = $false; Literal = $false; Value = $null }
	if (@($Command.CommandElements | Where-Object { $_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.Splatted }).Count -gt 0) { $hashResult; return }
	$colParameters = @($Command.CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] -and 'WorksheetName'.StartsWith($_.ParameterName, [StringComparison]::OrdinalIgnoreCase) })
	if ($colParameters.Count -ne 1 -or $colParameters[0].ParameterName -ine 'WorksheetName') { $hashResult; return }
	$colElements = @($Command.CommandElements)
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		$element = $colElements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($element.ParameterName -ine 'WorksheetName') { continue }

		$hashResult.Found = $true
		$argument = if ($null -ne $element.Argument) { $element.Argument } elseif ($index + 1 -lt $colElements.Count) { $colElements[$index + 1] } else { $null }
		if ($argument -is [Management.Automation.Language.StringConstantExpressionAst]) {
			$hashResult.Literal = $true
			$hashResult.Value = $argument.Value
		}
		$hashResult
		return
	}
	$hashResult
}

function Get-Ps1OutputExcelExportCommand {
	param($Statement)

	if ($Statement -isnot [Management.Automation.Language.PipelineAst]) { $null; return }
	$colElements = @($Statement.PipelineElements)
	if ($colElements.Count -eq 0) { $null; return }

	$last = $colElements[-1]
	if ($last -isnot [Management.Automation.Language.CommandAst]) { $null; return }
	$commandName = $last.GetCommandName()
	if ($null -eq $commandName) { $null; return }
	if (($commandName -split '\\')[-1] -ine 'Export-Excel') { $null; return }
	$last
}

function Get-Ps1StandardPublicOutputDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'PublicFunction')) { return }

	$moduleRoot = Split-Path (Split-Path $Path -Parent) -Parent
	$tableTypes = Get-Ps1OutputTableFormatType (Join-Path $moduleRoot 'xml/formats/table')

	foreach ($itemFunction in @(Get-Ps1OutputTopLevelFunction -Analysis $Analysis)) {
		Get-Ps1StandardPublicOutputFunctionDiagnostic -Analysis $Analysis `
			-Function $itemFunction `
			-TableTypes $tableTypes
	}
}

function Get-Ps1StandardPublicOutputFunctionDiagnostic {
	param($Analysis, $Function, $TableTypes)
	$Path = $Analysis.Path

	$model = Get-Ps1OutputFunctionModel -Function $Function `
		-Analysis $Analysis
	$hashSeen = @{}
	foreach ($itemType in @($model.CustomTypes)) {
		if ($hashSeen.ContainsKey($itemType.Name)) { continue }
		$hashSeen[$itemType.Name] = $true
		if ($TableTypes.ContainsKey($itemType.Name)) { continue }
		New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Add a table format view for '$($itemType.Name)'. Custom output requires a table view; a list view is optional." $itemType.Extent
	}

	foreach ($itemAttribute in @($model.Declaration.Attributes)) {
		foreach ($itemArgument in @($itemAttribute.PositionalArguments)) {
			if ($itemArgument -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			$name = $itemArgument.Value -replace '\[\]$', ''
			if ($name -notmatch '^D365Bap\.Tools\.' -or $hashSeen.ContainsKey($name) -or $TableTypes.ContainsKey($name)) { continue }
			$hashSeen[$name] = $true
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Add a table format view for '$name'. Custom output requires a table view; a list view is optional." $itemArgument.Extent
		}
	}

	$expectedWorksheet = Get-Ps1PublicOutputWorksheetName -Function $Function
	if ($model.IsCollection -and -not $model.HasExcelSwitch) {

		New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Add [switch] `$AsExcelOutput to $($Function.Name) and export the result. When -AsExcelOutput is set, call Export-Excel -WorksheetName '$expectedWorksheet' with a literal worksheet name, then use a bare return." $model.Declaration.CollectionAttribute.Extent
		return
	}
	if (-not $model.HasExcelSwitch) { return }

	Get-Ps1StandardPublicOutputExportDiagnostic -Analysis $Analysis `
		-Function $Function `
		-ExpectedWorksheet $expectedWorksheet
}

function Get-Ps1StandardPublicOutputExportDiagnostic {
	param($Analysis, $Function, [string] $ExpectedWorksheet)
	$Path = $Analysis.Path

	$colBlocks = @($Function.Body.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.IfStatementAst] -and
				(Test-Ps1OutputOwnedNode -Node $Node `
					-Function $Function)
			}, $true) | Where-Object {
			$condition = Get-Ps1OutputExcelConditionVariable -Condition $_.Clauses[0].Item1
			$condition -is [Management.Automation.Language.VariableExpressionAst] -and
			$condition.VariablePath.UserPath -eq 'AsExcelOutput'
		})

	if ($colBlocks.Count -eq 0) {
		New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Add the export block to $($Function.Name): when -AsExcelOutput is set, call Export-Excel -WorksheetName '$ExpectedWorksheet' with a literal worksheet name, then use a bare return." $Function.Extent
		return
	}

	foreach ($itemIf in $colBlocks) {
		if (@($itemIf.Clauses).Count -gt 1 -or $null -ne $itemIf.ElseClause) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Remove the elseif/else branches from the AsExcelOutput block in $($Function.Name). The export path ends with a bare return." $itemIf.Extent
			continue
		}

		if ($itemIf.Clauses[0].Item2.Traps.Count -gt 0) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Keep the AsExcelOutput block in $($Function.Name) to Export-Excel and a bare return; trap blocks are not part of this form." $itemIf.Extent
			continue
		}
		$tmpStatements = @($itemIf.Clauses[0].Item2.Statements)
		if ($tmpStatements.Count -eq 0) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Add the export and a bare return to the AsExcelOutput block in $($Function.Name)." $itemIf.Extent
			continue
		}

		if ($tmpStatements[0] -is [Management.Automation.Language.IfStatementAst]) {
			$guarded = @($tmpStatements[0].FindAll({
						param($Node)
						$Node -is [Management.Automation.Language.CommandAst] -and
						$null -ne $Node.GetCommandName() -and
						($Node.GetCommandName() -split '\\')[-1] -ieq 'Export-Excel'
					}, $true)).Count -gt 0
			if ($guarded) {
				New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Remove the result-count guard from the AsExcelOutput block in $($Function.Name). Export the collection directly and return." $itemIf.Extent
				continue
			}
		}

		if ($tmpStatements[0] -is [Management.Automation.Language.PipelineAst] -and $tmpStatements[0].Background) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' 'Run Export-Excel synchronously before the bare return; background export is not supported.' $itemIf.Extent
			continue
		}
		$exportCommand = Get-Ps1OutputExcelExportCommand -Statement $tmpStatements[0]
		if ($null -eq $exportCommand) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Start the AsExcelOutput block in $($Function.Name) with Export-Excel." $itemIf.Extent
			continue
		}

		$worksheet = Get-Ps1OutputExcelWorksheetParameter -Command $exportCommand
		if (-not $worksheet.Found) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Pass -WorksheetName '$ExpectedWorksheet' to Export-Excel in $($Function.Name)." $itemIf.Extent
			continue
		}
		if (-not $worksheet.Literal -or $worksheet.Value -cne $ExpectedWorksheet) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Use -WorksheetName '$ExpectedWorksheet' in the AsExcelOutput block of $($Function.Name)." $itemIf.Extent
			continue
		}

		if ($tmpStatements.Count -gt 2) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "Keep the AsExcelOutput block in $($Function.Name) to Export-Excel and a bare return." $itemIf.Extent
			continue
		}
		if ($tmpStatements.Count -eq 1) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "End the AsExcelOutput block in $($Function.Name) with a bare return after Export-Excel." $itemIf.Extent
			continue
		}
		if ($tmpStatements[1] -isnot [Management.Automation.Language.ReturnStatementAst] -or $null -ne $tmpStatements[1].Pipeline) {
			New-Ps1Diagnostic $Path 'PSUseStandardPublicOutput' "End the AsExcelOutput block in $($Function.Name) with a bare return after Export-Excel." $itemIf.Extent
		}
	}
}
