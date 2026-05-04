$scbBapLocations = {
    $azureRegions = Get-PSFConfigValue -FullName "d365bap.tools.bap.deploy.locations"

    @($azureRegions.Keys | Sort-Object)
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.locations" -ScriptBlock $scbBapLocations -Mode Simple
