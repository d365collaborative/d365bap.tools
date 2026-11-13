$scbTenantCapacity = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	$hashAliases = [ordered]@{
		'Ppac'              = 'Database, File, Log, CapacityPass, ApiCallCount'
		'Dataverse'         = 'Database, File, Log, CapacityPass, ApiCallCount'
		'FinOps'            = 'FinOpsDatabase, FinOpsFile'
		'M365'              = 'M365Database, M365EnvironmentCount'
		'Trial'             = 'TrialDatabase, TrialFile, TrialLog'
		'SubscriptionTrial' = 'SubscriptionTrialDatabase, SubscriptionTrialFile, SubscriptionTrialLog, SubscriptionTrialEnvironmentCount'
	}

	$colTypes = @(
		'Database', 'File', 'Log',
		'TrialDatabase', 'TrialFile', 'TrialLog',
		'SubscriptionTrialDatabase', 'SubscriptionTrialFile', 'SubscriptionTrialLog', 'SubscriptionTrialEnvironmentCount',
		'M365Database', 'M365EnvironmentCount',
		'CapacityPass', 'ApiCallCount',
		'FinOpsDatabase', 'FinOpsFile'
	)

	$filterWord = "$wordToComplete".Trim("'", '"')

	foreach ($itemAlias in $hashAliases.Keys) {
		if ($itemAlias -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $itemAlias -ToolTip $hashAliases[$itemAlias]
		}
	}

	foreach ($itemType in $colTypes) {
		if ($itemType -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $itemType -ToolTip $itemType
		}
	}
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.capacity" -ScriptBlock $scbTenantCapacity -Mode Full
