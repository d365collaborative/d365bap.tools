$scriptBlock = { Get-BapTenantDetail | Sort-Object Id | Select-Object -ExpandProperty Id }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details" -ScriptBlock $scriptBlock -Mode Simple

$scriptBlock = { Get-UdeDbJitCache | Sort-Object Id | Select-Object -ExpandProperty Id }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ude.dbjit.credentials" -ScriptBlock $scriptBlock -Mode Simple

$azureRegions = @{
    "UnitedStates"             = @("EastUS", "WestUS", "EastUS2", "CentralUS")
    "UnitedStatesFirstRelease" = @("EastUS", "WestUS", "EastUS2", "CentralUS")
    "Europe"                   = @("WestEurope", "NorthEurope")
    "Asia"                     = @("EastAsia", "SoutheastAsia")
    "Australia"                = @("AustraliaEast", "AustraliaSoutheast")
    "India"                    = @("CentralIndia", "SouthIndia")
    "Japan"                    = @("JapanEast", "JapanWest")
    "Canada"                   = @("CanadaCentral", "CanadaEast")
    "UnitedKingdom"            = @("UKSouth", "UKWest")
    "SouthAmerica"             = @("BrazilSouth")
    "France"                   = @("FranceCentral", "FranceSouth")
    "UnitedArabEmirates"       = @("UAENorth")
    "Germany"                  = @("GermanyNorth", "GermanyWestCentral")
    "Switzerland"              = @("SwitzerlandNorth", "SwitzerlandWest")
    "Norway"                   = @("NorwayEast", "NorwayWest")
    "Korea"                    = @("KoreaCentral", "KoreaSouth")
    "SouthAfrica"              = @("SouthAfricaNorth")
    "Sweden"                   = @("SwedenCentral")
}

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

    # Filter items based on the location and what the user has typed
    $filteredItems = $azureRegions[$location] | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object

    # Generate completion results
    foreach ($item in $filteredItems) {
        New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.regions" -ScriptBlock $scriptBlock -Mode Full

$scriptBlock = { @($azureRegions.Keys | Sort-Object) }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.locations" -ScriptBlock $scriptBlock -Mode Simple

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

    $templates = Get-BapDeployTemplate -Location $location -FnoOnly
    # Filter items based on the location and what the user has typed
    $filteredItems = $templates | `
        Select-Object -ExpandProperty Id | `
        Where-Object { $_ -like "$wordToComplete*" } | `
        Sort-Object

    # Generate completion results
    foreach ($item in $filteredItems) {
        New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.templates" -ScriptBlock $scriptBlock -Mode Full
