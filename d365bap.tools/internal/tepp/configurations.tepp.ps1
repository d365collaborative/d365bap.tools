$scbTenant = { Get-BapTenantDetail | Sort-Object Id | Select-Object -ExpandProperty Id }
Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details" -ScriptBlock $scbTenant -Mode Simple


$scbUdeDbJit = { Get-UdeDbJitCache | Sort-Object Id | Select-Object -ExpandProperty Id }
Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ude.dbjit.credentials" -ScriptBlock $scbUdeDbJit -Mode Simple


$scbBapRegions = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    # Get the value of the previous parameter (-Location)
    $location = $fakeBoundParameter['Location']

    # If no location is specified yet, return nothing or a default set (adjust as needed)
    if (-not $location) {
        return
    }

    $azureRegions = Get-PSFConfigValue -FullName "d365bap.tools.bap.deploy.locations"

    # Filter items based on the location and what the user has typed
    $filteredItems = $azureRegions[$location] | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object

    # Generate completion results
    foreach ($item in $filteredItems) {
        New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.regions" -ScriptBlock $scbBapRegions -Mode Full

$scbBapLocations = {
    $azureRegions = Get-PSFConfigValue -FullName "d365bap.tools.bap.deploy.locations"

    @($azureRegions.Keys | Sort-Object)
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.locations" -ScriptBlock $scbBapLocations -Mode Simple

<#
    Autocompletion for environments is a bit more complex as it needs to be refreshed based on the tenant that is currently set in context.
    The below implementation will refresh the environments every 15 minutes, but this can be adjusted as needed.
#>
Register-PSFTaskEngineTask -Name EnvironmentRefresh -Interval (New-TimeSpan -Minutes 15) -ResetTask -ScriptBlock {
    Set-PSFTaskEngineCache -Module d365bap.tools -Name Environments -Value (Get-BapEnvironment -FscmEnabled:$FscmEnabled).EnvName
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.environments" -ScriptBlock {
    Get-PSFTaskEngineCache -Module d365bap.tools -Name Environments
}

$commands = Get-Command -Module d365bap.tools | Where-Object { $_.Parameters.Keys -contains "EnvironmentId" }

foreach ($command in $commands) {
    Register-PSFTeppArgumentCompleter -Command $command.Name -Parameter EnvironmentId -Name "d365bap.tools.tepp.environments"
}

<#
    Auto lookup the version for the environment
#>
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

    $updateVersions = Get-PpacD365PlatformUpdate -EnvironmentId $environmentId

    # Generate completion results
    foreach ($item in $updateVersions) {
        New-PSFTeppCompletionResult -CompletionText $item.Version -ToolTip $item.Platform
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.env.temp.versions" -ScriptBlock $scbEnvVersion -Mode Full

<#
    For PPAC RBAC roles, we will read the roles from a static JSON file that is included in the module. This is because the list of roles is not expected to change frequently, and it avoids the need for making API calls during autocompletion which can be slow and may have throttling issues.
#>
$scbPpacRbacRoles = {
    $pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"

    $rbacRoles = Get-Content `
        -Path "$pathMisc\Ppac.Rbac.Roles.json" `
        -Raw | ConvertFrom-Json

    $rbacRoles.roleDefinitionName | Sort-Object
}

Register-PSFTeppScriptblock `
    -Name "d365bap.tools.tepp.ppac.rbac.roles" `
    -ScriptBlock $scbPpacRbacRoles `
    -Mode Simple

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
