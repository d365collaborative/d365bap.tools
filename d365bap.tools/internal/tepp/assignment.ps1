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