$roleCommands = @(
	'Get-PpacRbacRole',
	'Add-PpacRbacRoleMember',
	'Get-PpacRbacRoleMember',
	'Add-PpacEnvironmentRbacRoleMember',
	'Get-PpacEnvironmentRbacRoleMember',
	'Add-PpacEnvironmentGroupRbacRoleMember',
	'Get-PpacEnvironmentGroupRbacRoleMember'
)
Register-ArgumentCompleter -CommandName $roleCommands -ParameterName Role -ScriptBlock {
	param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

	$null = $commandAst
	$word = "$wordToComplete".Trim("'", '"').Replace("''", "'")
	$selected = @()
	$parameter = (Get-Command $commandName -ErrorAction SilentlyContinue).Parameters[$parameterName]
	if ($parameter.ParameterType.IsArray) { $selected = @($fakeBoundParameters[$parameterName]) }
	$roles = @(Get-BapRbacRoleCatalog | Sort-Object roleDefinitionName -Unique)
	$selectedIds = @($roles | Where-Object {
			$_.roleDefinitionName -in $selected -or $_.roleDefinitionId -in $selected
		} | ForEach-Object roleDefinitionId)
	foreach ($role in $roles) {
		if ($role.roleDefinitionId -in $selectedIds) { continue }
		$name = "$($role.roleDefinitionName)"
		$id = "$($role.roleDefinitionId)"
		$value = if ($name.StartsWith($word, [StringComparison]::OrdinalIgnoreCase)) { $name }
		elseif ($id.StartsWith($word, [StringComparison]::OrdinalIgnoreCase)) { $id }
		else { continue }
		$quoted = "'" + $value.Replace("'", "''") + "'"
		[Management.Automation.CompletionResult]::new($quoted, $name, 'ParameterValue', "$name ($id): $($role.description)")
	}
}
