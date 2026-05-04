<#
# Example:
Register-PSFTeppArgumentCompleter -Command Get-Alcohol -Parameter Type -Name d365bap.tools.alcohol
#>

Register-PSFTeppArgumentCompleter `
    -Command Get-BapTenantDetail `
    -Parameter Id `
    -Name "d365bap.tools.tepp.tenant.details"

Register-PSFTeppArgumentCompleter `
    -Command Set-BapTenantDetail `
    -Parameter Id `
    -Name "d365bap.tools.tepp.tenant.details"

Register-PSFTeppArgumentCompleter `
    -Command Switch-BapTenant `
    -Parameter Id `
    -Name "d365bap.tools.tepp.tenant.details"

Register-PSFTeppArgumentCompleter `
    -Command Remove-BapTenantDetail `
    -Parameter Id `
    -Name "d365bap.tools.tepp.tenant.details"

Register-PSFTeppArgumentCompleter `
    -Command Get-UdeDbJitCache `
    -Parameter Id `
    -Name "d365bap.tools.tepp.ude.dbjit.credentials"

Register-PSFTeppArgumentCompleter `
    -Command Set-UdeDbJitCache `
    -Parameter Id `
    -Name "d365bap.tools.tepp.ude.dbjit.credentials"

Register-PSFTeppArgumentCompleter `
    -Command Start-UdeDbSsms `
    -Parameter Id `
    -Name "d365bap.tools.tepp.ude.dbjit.credentials"

Register-PSFTeppArgumentCompleter `
    -Command Get-PpacDeployLocation `
    -Parameter Name `
    -Name "d365bap.tools.tepp.bap.locations"

Register-PSFTeppArgumentCompleter `
    -Command New-UnifiedEnvironment `
    -Parameter Location `
    -Name "d365bap.tools.tepp.bap.locations"

Register-PSFTeppArgumentCompleter `
    -Command New-UnifiedEnvironment `
    -Parameter Region `
    -Name "d365bap.tools.tepp.bap.regions"

Register-PSFTeppArgumentCompleter `
    -Command Invoke-PpacD365PlatformUpdate `
    -Parameter Version `
    -Name "d365bap.tools.tepp.env.temp.versions"

Register-PSFTeppArgumentCompleter `
    -Command Add-PpacRbacRoleMember `
    -Parameter Role `
    -Name "d365bap.tools.tepp.ppac.rbac.roles"

Register-PSFTeppArgumentCompleter `
    -Command Get-PpacRbacRoleMember `
    -Parameter Role `
    -Name "d365bap.tools.tepp.ppac.rbac.roles"

Register-PSFTeppArgumentCompleter `
    -Command Add-PpacRbacRoleMember `
    -Parameter Scope `
    -Name "d365bap.tools.tepp.ppac.rbac.role.temp.scopes"

Register-PSFTeppArgumentCompleter `
    -Command Get-FscmRestService `
    -Parameter TraverseTo `
    -Name "d365bap.tools.tepp.fscm.rest.service.traverse"
