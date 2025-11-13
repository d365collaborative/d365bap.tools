<#
.SYNOPSIS
Get UDE VS package deploys.

.DESCRIPTION
Gets the UDE package deploys from Visual Studio, that are stored in the local temp folder.

.PARAMETER All
Instructs the cmdlet to return all package deploys.

.PARAMETER OpenFolder
Instructs the cmdlet to open the folder containing the package deploys.

.EXAMPLE
PS C:\> Get-UdeVsPackageDeploy

This will retrieve the latest UDE VS package deploy from the local temp folder.

.EXAMPLE
PS C:\> Get-UdeVsPackageDeploy -All

This will retrieve all UDE VS package deploys from the local temp folder.

.EXAMPLE
PS C:\> Get-UdeVsPackageDeploy -OpenFolder

This will open the folder containing the UDE VS package deploys in File Explorer.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeVsPackageDeploy {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $All,

        [switch] $OpenFolder
    )

    begin {
    }
    
    process {
        $path = "$env:LOCALAPPDATA\Temp\finOpsPackaging"
        
        if ($OpenFolder) {
            Start-Process $path
        }

        $files = Get-ChildItem -Path "$path\*\PackageAssets\*.zip" | Where-Object { $_.Name -ne 'DefaultDevSolution_managed.zip' } | Sort-Object LastWriteTime -Descending

        $resCol = @(
            foreach ($file in $files) {
                $file | Select-PSFObject -TypeName "D365Bap.Tools.VsPackageDeploy" `
                    -Property @{ Label = "Id"; Expression = { $_.Directory.Parent.Name } },
                @{ Label = "Package"; Expression = { $_.Name.Replace("_1_0_0_1_managed.zip", "") } },
                "Length as Size to PSFSize",
                "LastWriteTime as LastModified",
                *
            }
        )

        if (-not $All) {
            $resCol = $resCol | Select-Object -First 1
        }

        $resCol
    }
    
    end {
    }
}