$scbPpacSecurityRoles = {
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

    $colRoles = Get-PpacSecurityRole -EnvironmentId $environmentId

    # Generate completion results
    foreach ($item in $colRoles) {
        New-PSFTeppCompletionResult -CompletionText $item.Name -ToolTip $item.PpacRoleId
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ppac.security.roles" -ScriptBlock $scbPpacSecurityRoles -Mode Full
