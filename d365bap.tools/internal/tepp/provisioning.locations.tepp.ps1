$scbProvisioningLocations = {
    $locations = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.locations' -Fallback @()
    @($locations | ForEach-Object { $_.name } | Sort-Object -Unique)
}

Register-PSFTeppScriptblock -Name 'd365bap.tools.tepp.provisioning.locations' -ScriptBlock $scbProvisioningLocations -Mode Simple
