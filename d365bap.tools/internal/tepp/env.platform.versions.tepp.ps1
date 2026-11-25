$scbEnvVersion = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	# Get the value of the previous parameter (-EnvironmentId)
	$environmentId = $fakeBoundParameter['EnvironmentId']

	# If no environmentId is specified yet, return nothing or a default set (adjust as needed)
	if (-not $environmentId) {
		return
	}

	$filterWord = "$wordToComplete".Trim("'", '"')

	$updateVersions = Get-PpacD365PlatformUpdate -EnvironmentId $environmentId -ErrorAction SilentlyContinue

	# Generate completion results
	foreach ($item in $updateVersions) {
		if ($item.Version -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $item.Version -ToolTip $item.Platform
		}
	}
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.env.temp.versions" -ScriptBlock $scbEnvVersion -Mode Full

$scbEnvD365Version = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	# Get the value of the previous parameter (-EnvironmentId)
	$environmentId = $fakeBoundParameter['EnvironmentId']

	# If no environmentId is specified yet, return nothing or a default set (adjust as needed)
	if (-not $environmentId) {
		return
	}

	$filterWord = "$wordToComplete".Trim("'", '"')

	$d365Versions = Get-PpacD365Version -EnvironmentId $environmentId -ErrorAction SilentlyContinue

	# Generate completion results
	foreach ($item in $d365Versions) {
		if ($item.Version -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $item.Version -ToolTip $item.Platform
		}
	}
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.env.d365.versions" -ScriptBlock $scbEnvD365Version -Mode Full
