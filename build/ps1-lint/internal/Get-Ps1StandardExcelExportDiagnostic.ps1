$script:Ps1ExcelWorksheetExemptions = @{
	'Get-UdeConnection' = 'UdeConnection'
}

function Get-Ps1ExcelConditionVariable {
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

function Test-Ps1ExcelSwitchParameter {
	param($Function)

	@($Function.Body.ParamBlock.Parameters | Where-Object {
			if ($_.Name.VariablePath.UserPath -ne 'AsExcelOutput') { $false; return }
			@($_.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter')
				}).Count -gt 0
		}).Count -gt 0
}

function Get-Ps1ExcelWorksheetParameter {
	param($Command)

	$hashResult = @{ Found = $false; Literal = $false; Value = $null }
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

function Get-Ps1ExcelExportCommand {
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

function Get-Ps1StandardExcelExportDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'PublicFunction')) { return }

	foreach ($itemFunction in @(Get-Ps1AstNode $Analysis FunctionDefinitionAst)) {
		if ($null -eq $itemFunction.Body.ParamBlock) { continue }
		if (-not (Test-Ps1ExcelSwitchParameter -Function $itemFunction)) { continue }

		$tmpBlocks = @($itemFunction.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.IfStatementAst] }, $true) | Where-Object {
				$condition = Get-Ps1ExcelConditionVariable -Condition $_.Clauses[0].Item1
				$condition -is [Management.Automation.Language.VariableExpressionAst] -and
				$condition.VariablePath.UserPath -eq 'AsExcelOutput'
			})

		if ($tmpBlocks.Count -eq 0) {
			$forwards = @($itemFunction.Body.FindAll({
						param($Node)
						$Node -is [Management.Automation.Language.CommandAst] -and
						@($Node.CommandElements | Where-Object {
								$_ -is [Management.Automation.Language.CommandParameterAst] -and
								$_.ParameterName -ieq 'AsExcelOutput'
							}).Count -gt 0
					}, $true)).Count -gt 0
			if ($forwards) { continue }

			New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Add the export block to $($itemFunction.Name): when -AsExcelOutput is set, export the result with -WorksheetName and return." $itemFunction.Name.Extent
			continue
		}

		$expectedWorksheet = if ($script:Ps1ExcelWorksheetExemptions.ContainsKey($itemFunction.Name)) {
			$script:Ps1ExcelWorksheetExemptions[$itemFunction.Name]
		}
		else {
			$itemFunction.Name
		}

		foreach ($itemIf in $tmpBlocks) {
			if (@($itemIf.Clauses).Count -gt 1 -or $null -ne $itemIf.ElseClause) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Remove the elseif/else branches from the AsExcelOutput block in $($itemFunction.Name). The export path ends with a bare return." $itemIf.Extent
				continue
			}

			$tmpStatements = @($itemIf.Clauses[0].Item2.Statements)
			if ($tmpStatements.Count -eq 0) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Add the export and a bare return to the AsExcelOutput block in $($itemFunction.Name)." $itemIf.Extent
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
					New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Remove the result-count guard from the AsExcelOutput block in $($itemFunction.Name). Export the collection directly and return." $itemIf.Extent
					continue
				}
			}

			$exportCommand = Get-Ps1ExcelExportCommand -Statement $tmpStatements[0]
			if ($null -eq $exportCommand) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Start the AsExcelOutput block in $($itemFunction.Name) with Export-Excel." $itemIf.Extent
				continue
			}

			$worksheet = Get-Ps1ExcelWorksheetParameter -Command $exportCommand
			if (-not $worksheet.Found) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Pass -WorksheetName '$expectedWorksheet' to Export-Excel in $($itemFunction.Name)." $itemIf.Extent
				continue
			}
			if ($worksheet.Literal -and $worksheet.Value -cne $expectedWorksheet) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Use -WorksheetName '$expectedWorksheet' in the AsExcelOutput block of $($itemFunction.Name)." $itemIf.Extent
				continue
			}

			if ($tmpStatements.Count -gt 2) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "Keep the AsExcelOutput block in $($itemFunction.Name) to Export-Excel and a bare return." $itemIf.Extent
				continue
			}
			if ($tmpStatements.Count -eq 1) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "End the AsExcelOutput block in $($itemFunction.Name) with a bare return after Export-Excel." $itemIf.Extent
				continue
			}
			if ($tmpStatements[1] -isnot [Management.Automation.Language.ReturnStatementAst] -or $null -ne $tmpStatements[1].Pipeline) {
				New-Ps1Diagnostic $Path 'PSUseStandardExcelExport' "End the AsExcelOutput block in $($itemFunction.Name) with a bare return after Export-Excel." $itemIf.Extent
			}
		}
	}
}
