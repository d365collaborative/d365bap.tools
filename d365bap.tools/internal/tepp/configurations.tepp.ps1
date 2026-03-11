$scriptBlock = { Get-BapTenantDetail | Sort-Object Id | Select-Object -ExpandProperty Id }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details" -ScriptBlock $scriptBlock -Mode Simple

$scriptBlock = { Get-UdeDbJitCache | Sort-Object Id | Select-Object -ExpandProperty Id }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ude.dbjit.credentials" -ScriptBlock $scriptBlock -Mode Simple

$scriptBlock = {
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

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.regions" -ScriptBlock $scriptBlock -Mode Full

$scriptBlock = {
    $azureRegions = Get-PSFConfigValue -FullName "d365bap.tools.bap.deploy.locations"

    @($azureRegions.Keys | Sort-Object)
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.locations" -ScriptBlock $scriptBlock -Mode Simple

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
$scriptBlock = {
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

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.env.temp.versions" -ScriptBlock $scriptBlock -Mode Full