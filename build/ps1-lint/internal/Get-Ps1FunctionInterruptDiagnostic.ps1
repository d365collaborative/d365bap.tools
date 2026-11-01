function Get-Ps1FunctionInterruptOwner {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) { return $parent }
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1FunctionInterruptCommandName {
	param($Command)

	$name = $Command.GetCommandName()
	if ($null -eq $name) { return $null }
	($name -split '\\')[-1]
}

function New-Ps1FunctionInterruptDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidOrphanPSFFunctionInterruptCheck'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1FunctionInterruptDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		$objProcess = $itemFunction.Body.ProcessBlock
		if ($null -eq $objProcess) { continue }

		$tmpPreceding = [System.Collections.Generic.List[object]]::new()
		if ($null -ne $itemFunction.Body.DynamicParamBlock) {
			foreach ($itemStatement in $itemFunction.Body.DynamicParamBlock.Statements) { $tmpPreceding.Add($itemStatement) }
		}
		if ($null -ne $itemFunction.Body.BeginBlock) {
			foreach ($itemStatement in $itemFunction.Body.BeginBlock.Statements) { $tmpPreceding.Add($itemStatement) }
		}

		foreach ($itemStatement in $objProcess.Statements) {
			$hasPrecedingCommand = @($tmpPreceding | Where-Object {
					@($_.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)).Count -gt 0
				}).Count -gt 0

			foreach ($itemCommand in $itemStatement.FindAll({
						param($Node)
						$Node -is [Management.Automation.Language.CommandAst] -and
						(Get-Ps1FunctionInterruptCommandName $Node) -eq 'Test-PSFFunctionInterrupt'
					}, $true)) {
				if ((Get-Ps1FunctionInterruptOwner -Node $itemCommand) -ne $itemFunction) { continue }
				if ($hasPrecedingCommand) { continue }

				$tmpPriorInStatement = @($itemStatement.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true) | Where-Object {
						$_.Extent.StartOffset -lt $itemCommand.Extent.StartOffset -and
						(Get-Ps1FunctionInterruptCommandName $_) -ne 'Test-PSFFunctionInterrupt'
					})
				if ($tmpPriorInStatement.Count -gt 0) { continue }

				New-Ps1FunctionInterruptDiagnostic -Path $Path -Extent $itemCommand.Extent `
					-Message 'Test-PSFFunctionInterrupt in a process block has no preceding command that can interrupt the function. Move the check after the command that can stop, or remove it.'
			}

			$tmpPreceding.Add($itemStatement)
		}
	}
}
