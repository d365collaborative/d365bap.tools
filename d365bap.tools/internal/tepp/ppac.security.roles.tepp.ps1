$scbPpacSecurityRoles = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	$filterWord = "$wordToComplete".Trim("'", '"')

	# Get the value of the previous parameter (-EnvironmentId)
	$environmentId = $fakeBoundParameter['EnvironmentId']

	# If no environmentId is specified yet, return nothing
	if (-not $environmentId) {
		return
	}

	$colRoles = Get-PpacSecurityRole -EnvironmentId $environmentId -ErrorAction SilentlyContinue

	# Generate completion results - filter by typed prefix, otherwise TAB restarts from top
	foreach ($item in $colRoles) {
		if ($item.Name -like "$filterWord*" -or $item.PpacRoleId -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $item.Name -ToolTip $item.PpacRoleId
		}
	}
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ppac.security.roles" -ScriptBlock $scbPpacSecurityRoles -Mode Full
