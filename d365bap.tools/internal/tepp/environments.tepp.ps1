Register-PSFTaskEngineTask -Name EnvironmentRefresh -Interval (New-TimeSpan -Minutes 15) -ResetTask -ScriptBlock {
	Set-PSFTaskEngineCache -Module d365bap.tools -Name Environments -Value (Get-Environment -ErrorAction SilentlyContinue).EnvName
}

$scbEnvironments = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$filterWord = "$wordToComplete".Trim("'", '"')
		$cached = @(Get-PSFTaskEngineCache -Module d365bap.tools -Name Environments -ErrorAction SilentlyContinue | Where-Object { $_ })
		if (-not $cached -or $cached.Count -eq 0) {
			$cached = @(Get-Environment -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnvName -Unique | Where-Object { $_ })
		}
		$merged = @($cached) | Sort-Object -Unique | Where-Object { $_ -like "$filterWord*" }

		foreach ($v in $merged) {
			$escaped = $v -replace "'", "''"
			$quoted = "'$escaped'"
			[System.Management.Automation.CompletionResult]::new($quoted, $v, 'ParameterValue', $v)
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.environments" -ScriptBlock $scbEnvironments -Mode Full

$teppParameters = @("EnvironmentId", "SourceEnvironmentId", "DestinationEnvironmentId")

foreach ($paramName in $teppParameters) {
	$commands = Get-ChildItem function: | Where-Object {
		(Get-Command $_.Name -CommandType Function -ErrorAction SilentlyContinue).Parameters.Keys -contains $paramName
	}

	foreach ($command in $commands) {
		Register-PSFTeppArgumentCompleter -Command $command.Name -Parameter $paramName -Name "d365bap.tools.tepp.environments"
	}
}
