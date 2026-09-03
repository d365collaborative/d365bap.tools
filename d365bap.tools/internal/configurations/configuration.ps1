<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'd365bap.tools' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'd365bap.tools' -Name 'Import.DoDotSource' -Value $true -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'd365bap.tools' -Name 'Import.IndividualFiles' -Value $true -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

Set-PSFConfig -FullName "d365bap.tools.tenant.details" -Value @{} -Initialize -Description "Object that stores different Azure Tenants and their details."

Set-PSFConfig -FullName "d365bap.tools.path.azcopy" -Value "C:\temp\d365bap.tools\AzCopy\AzCopy.exe" -Initialize -Description "Path to the default location where AzCopy.exe is located."

Set-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Value @{} -Initialize -Description "Object that stores different Ude Database JIT credentials and their details."

Set-PSFConfig -FullName "d365bap.tools.bap.deploy.locations" -Value @{
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
} -Initialize -Description "Object that stores different BAP deploy locations and their details."

Set-PSFConfig `
    -FullName "d365bap.tools.internal.misc.path" `
    -Value "$($script:ModuleRoot)\internal\misc" `
    -Initialize `
    -Description "Path to the root of the module. This is used for various internal operations, such as reading static files that are included in the module."

Set-PSFConfig -FullName "d365bap.tools.ppac.security.accesslevels" -Value @{
    "User"                    = "Basic"
    "BusinessUnit"            = "Local"
    "ParentChildBusinessUnit" = "Deep"
    "Organization"            = "Global"
} -Initialize -Description "Object that translates the Power Platform admin center access level naming to the Dataverse privilege depth naming, which is the only naming accepted by the Dataverse Web API."

Set-PSFConfig -FullName "d365bap.tools.ppac.security.depths" -Value @{
    "0"      = "User"
    "1"      = "Business Unit"
    "2"      = "Parent: Child Business Unit"
    "3"      = "Organization"
    "Basic"  = "User"
    "Local"  = "Business Unit"
    "Deep"   = "Parent: Child Business Unit"
    "Global" = "Organization"
} -Initialize -Description "Object that translates the Dataverse privilege depth values to the Power Platform admin center access level naming, used when displaying the table privileges of a security role."