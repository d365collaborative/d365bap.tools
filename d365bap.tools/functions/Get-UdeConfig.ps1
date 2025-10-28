
<#
    .SYNOPSIS
        Gets UDE configuration information.
        
    .DESCRIPTION
        Retrieves configuration settings for the User Development Environment (UDE).
        
        Is based on the details that the developer can see from within Visual Studio when working with UDE.
        
    .PARAMETER Name
        The name of the UDE configuration.
        
    .PARAMETER Active
        Instructs the function to only return the active UDE configuration.
        
    .EXAMPLE
        PS C:\> Get-UdeConfig
        
        This will retrieve all available UDE configurations.
        
    .EXAMPLE
        PS C:\> Get-UdeConfig -Name "ContosoUdeConfig"
        
        This will retrieve the UDE configuration with the name "ContosoUdeConfig".
        
    .EXAMPLE
        PS C:\> Get-UdeConfig -Active
        
        This will retrieve the currently active UDE configuration.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeConfig {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $Name = "*",

        [switch] $Active,

        [switch] $AsExcelOutput
    )

    begin {
    }
    
    process {
        $path = "$env:LOCALAPPDATA\Microsoft\Dynamics365\XPPConfig"
        
        $pathCurConf = Get-ItemPropertyValue `
            -Path "HKCU:\Software\Microsoft\Dynamics\AX7\Development\Configurations" `
            -Name CurrentMetadataConfig
        
        $configs = Get-ChildItem -Path "$path\*.json"

        $resCol = @(
            foreach ($config in $configs) {
                $conObj = Get-Content -Path $config.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

                if (-not ($config.Name.Split("_")[0] -like $Name)) { continue }

                $conObj | Add-Member -NotePropertyName "LocalPackages" -NotePropertyValue $($conObj.FrameworkDirectory | Split-Path -Parent | Split-Path -Leaf)

                ([PSCustomObject]$conObj) | Select-PSFObject -TypeName "D365Bap.Tools.UdeConfig" `
                    -Property @{ Name = "Name"; Expression = { $config.Name.Split("_")[0] } },
                @{ Name = "Active"; Expression = { $config.FullName -eq $pathCurConf } },
                "FrameworkDirectory as PackagesLocalDirectory",
                "ModelStoreFolder as MetadataDirectory",
                "CrossReferencesDatabaseName as XRefDatabase",
                "DefaultModelForNewProjects as DefaultModel",
                "LocalPackages as PackagesVersion",
                *
            }
        )

        if ($Active) {
            $resCol = $resCol | Where-Object { $_.Active -eq $true }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -NoNumberConversion PackagesVersion, LocalPackages
            return
        }

        $resCol
    }

    
    end {
    }
}

# New-Item -ItemType SymbolicLink -Path 'C:\Users\MötzJensen\AppData\Local\Microsoft\Dynamics365\RuntimeSymLinks\es-feature-001\ZZZZ__CustomXppMetadata' -Target 'C:\UDE_GIT\Essence\es-feature-001'