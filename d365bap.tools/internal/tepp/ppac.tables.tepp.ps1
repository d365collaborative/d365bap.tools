$scbPpacTables = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	# Get the value of the previous parameter (-EnvironmentId)
	$environmentId = $fakeBoundParameter['EnvironmentId']

	# If no environmentId is specified yet, return nothing
	if (-not $environmentId) {
		return
	}

	$filterWord = "$wordToComplete".Trim("'", '"')

	$colTables = Get-PpacTable -EnvironmentId $environmentId -ErrorAction SilentlyContinue

	# Generate completion results
	foreach ($item in $colTables) {
		if ($item.Name -like "$filterWord*" -or $item.TableName -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $item.Name -ToolTip $item.TableName
		}
	}
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ppac.tables" -ScriptBlock $scbPpacTables -Mode Full
