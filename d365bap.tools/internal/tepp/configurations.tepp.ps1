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
