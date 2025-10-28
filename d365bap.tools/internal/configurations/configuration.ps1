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