$script:Ps1CatchErrorLevels = @('Critical', 'Important', 'Output', 'Host', 'Significant', 'Warning')

function Get-Ps1CatchOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
			$parent
			return
		}
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1CatchEnclosing {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.CatchClauseAst]) {
			$parent
			return
		}
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1CatchCommandArgument {
	param($Command, [string] $Name)

	$colElements = @($Command.CommandElements)
	for ($index = 0; $index -lt $colElements.Count; $index++) {
		$element = $colElements[$index]
		if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
		if ($element.ParameterName -ine $Name) { continue }
		if ($null -ne $element.Argument) {
			$element.Argument
			return
		}
		if ($index + 1 -lt $colElements.Count) {
			$colElements[$index + 1]
			return
		}
	}
	$null
}

function Get-Ps1CatchCommand {
	param($Catch, [string] $Name)

	$owner = Get-Ps1CatchOwnerFunction -Node $Catch
	foreach ($itemCommand in $Catch.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine $Name) { continue }
		if ((Get-Ps1CatchEnclosing -Node $itemCommand) -ne $Catch) { continue }
		if ((Get-Ps1CatchOwnerFunction -Node $itemCommand) -ne $owner) { continue }

		$itemCommand
	}
}

function Get-Ps1CatchLogCommand {
	param($Catch)

	foreach ($itemCommand in @(Get-Ps1CatchCommand -Catch $Catch -Name 'Write-PSFMessage')) {
		$level = Get-Ps1CatchCommandArgument -Command $itemCommand -Name 'Level'
		if ($level -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
		if ($level.Value -notin $script:Ps1CatchErrorLevels) { continue }
		$itemCommand
	}
}

function New-Ps1SingleCatchErrorChannelDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseSingleCatchErrorChannel'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1SingleCatchErrorChannelDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemCatch in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CatchClauseAst] }, $true)) {
		$tmpLog = @(Get-Ps1CatchLogCommand -Catch $itemCatch)
		if ($tmpLog.Count -eq 0) { continue }

		$tmpStop = @(Get-Ps1CatchCommand -Catch $itemCatch -Name 'Stop-PSFFunction')
		if ($tmpStop.Count -eq 0) { continue }

		New-Ps1SingleCatchErrorChannelDiagnostic -Path $Path -Extent $itemCatch.Extent -Message 'The catch block logs with Write-PSFMessage and stops with Stop-PSFFunction. Keep one error channel: log and return, or stop without a separate log.'
	}
}
