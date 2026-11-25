$scbRestTraverse = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	$values = "ServiceGroup", "Service", "Operation", "Detail"

	$filterWord = "$wordToComplete".Trim("'", '"')

	# Generate completion results
	foreach ($item in $values) {
		if ($item -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
		}
	}
}

Register-PSFTeppScriptblock `
	-Name "d365bap.tools.tepp.fscm.rest.service.traverse" `
	-ScriptBlock $scbRestTraverse `
	-Mode Full
