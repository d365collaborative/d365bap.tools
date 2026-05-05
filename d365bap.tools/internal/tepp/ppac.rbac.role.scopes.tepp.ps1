$scbRbacRoleScopes = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    # Get the value of the previous parameter (-Role)
    $roleName = $fakeBoundParameter['Role']

    # If no role is specified yet, return nothing or a default set (adjust as needed)
    if (-not $roleName) {
        return
    }

    $pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"
    $rbacRoles = Get-Content `
        -Path "$pathMisc\Ppac.Rbac.Roles.json" `
        -Raw | ConvertFrom-Json

    $role = $rbacRoles | `
        Where-Object { $_.roleDefinitionName -eq $roleName } | `
        Select-Object -First 1

    foreach ($item in $role.assignableScopes) {
        New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ppac.rbac.role.temp.scopes" `
    -ScriptBlock $scbRbacRoleScopes `
    -Mode Full
