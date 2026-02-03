<#
# Example:
Register-PSFTeppArgumentCompleter -Command Get-Alcohol -Parameter Type -Name d365bap.tools.alcohol
#>

Register-PSFTeppArgumentCompleter -Command Get-BapTenantDetail -Parameter Id -Name "d365bap.tools.tepp.tenant.details"
Register-PSFTeppArgumentCompleter -Command Set-BapTenantDetail -Parameter Id -Name "d365bap.tools.tepp.tenant.details"
Register-PSFTeppArgumentCompleter -Command Switch-BapTenant -Parameter Id -Name "d365bap.tools.tepp.tenant.details"

Register-PSFTeppArgumentCompleter -Command Get-UdeDbJitCache -Parameter Id -Name "d365bap.tools.tepp.ude.dbjit.credentials"
Register-PSFTeppArgumentCompleter -Command Set-UdeDbJitCache -Parameter Id -Name "d365bap.tools.tepp.ude.dbjit.credentials"
Register-PSFTeppArgumentCompleter -Command Start-UdeDbSsms -Parameter Id -Name "d365bap.tools.tepp.ude.dbjit.credentials"

Register-PSFTeppArgumentCompleter -Command Get-BapDeployLocation -Parameter Name -Name "d365bap.tools.tepp.bap.locations"
Register-PSFTeppArgumentCompleter -Command Get-BapDeployTemplate -Parameter Location -Name "d365bap.tools.tepp.bap.locations"
Register-PSFTeppArgumentCompleter -Command Get-BapDeployParameter -Parameter Location -Name "d365bap.tools.tepp.bap.locations"

Register-PSFTeppArgumentCompleter -Command New-UdeEnvironment -Parameter Location -Name "d365bap.tools.tepp.bap.locations"
Register-PSFTeppArgumentCompleter -Command New-UdeEnvironment -Parameter Region -Name "d365bap.tools.tepp.bap.regions"
Register-PSFTeppArgumentCompleter -Command New-UdeEnvironment -Parameter FnoTemplate -Name "d365bap.tools.tepp.bap.templates"

Register-PSFTeppArgumentCompleter -Command New-UseEnvironment -Parameter Location -Name "d365bap.tools.tepp.bap.locations"
Register-PSFTeppArgumentCompleter -Command New-UseEnvironment -Parameter Region -Name "d365bap.tools.tepp.bap.regions"
Register-PSFTeppArgumentCompleter -Command New-UdeEnvironment -Parameter FnoTemplate -Name "d365bap.tools.tepp.bap.templates"
