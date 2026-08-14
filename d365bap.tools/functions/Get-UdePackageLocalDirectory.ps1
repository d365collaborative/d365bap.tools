
<#
    .SYNOPSIS
        Gets local UDE PackagesLocalDirectory paths
        
    .DESCRIPTION
        Finds installed packages versions under the local Dynamics 365 developer folder
        
        Returns the full PackagesLocalDirectory path for each matching version, sorted ascending by version
        
    .PARAMETER Version
        Packages version to include. Supports wildcards. Defaults to '*'
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory
        
        Lists all local PackagesLocalDirectory paths.
        It will only include versions where PackagesLocalDirectory exists.
        
    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -Version '10.0.2345*'
        
        Lists PackagesLocalDirectory paths for matching package versions.
        It will support wildcard search on the version number.
        
    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -AsExcelOutput
        
        Lists all local PackagesLocalDirectory paths.
        It will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdePackageLocalDirectory {
    [CmdletBinding()]
    [OutputType('D365Bap.Tools.UdePackageLocalDirectory')]
    param (
        [string] $Version = '*',

        [switch] $AsExcelOutput
    )

    begin {
        $pathPackagesRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Dynamics365'
    }

    process {
        $resCol = @(
            Get-ChildItem -LiteralPath $pathPackagesRoot -Directory |
                Where-Object { $_.Name -match '^\d+(\.\d+)+$' -and $_.Name -like $Version } |
                ForEach-Object {
                    $pathPackagesLocal = Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory'
                    if (-not (Test-Path -LiteralPath $pathPackagesLocal)) { return }

                    [PSCustomObject]@{
                        PackagesVersion        = $_.Name
                        PackagesLocalDirectory = $pathPackagesLocal
                    }
                } |
                Sort-Object { [version]$_.PackagesVersion }
        )

        $output = $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.UdePackageLocalDirectory' -Property *

        if ($AsExcelOutput) {
            $output | Export-Excel -WorksheetName "Get-UdePackageLocalDirectory" `
                -NoNumberConversion PackagesVersion
            return
        }

        $output
    }

    end {
    }
}