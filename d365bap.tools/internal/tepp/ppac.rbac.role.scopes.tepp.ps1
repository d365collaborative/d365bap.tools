$scbRbacRoleScopes = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	$filterWord = "$wordToComplete".Trim("'", '"')

	# Get the value of the previous parameter (-Role)
	$roleName = $fakeBoundParameter['Role']

	# If no role is specified yet, return nothing or a default set (adjust as needed)
	if (-not $roleName) {
		return
	}

	$rbacRoles = @(Get-BapRbacRoleCatalog)

	$role = $rbacRoles | `
		Where-Object { $_.roleDefinitionName -eq $roleName } | `
		Select-Object -First 1

	foreach ($item in $role.assignableScopes) {
		if ($item -like "$filterWord*") {
			New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
		}
	}
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ppac.rbac.role.temp.scopes" `
	-ScriptBlock $scbRbacRoleScopes `
	-Mode Full
