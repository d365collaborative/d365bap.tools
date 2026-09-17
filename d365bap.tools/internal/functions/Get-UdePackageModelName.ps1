
<#
    .SYNOPSIS
        Get the model name from a UDE package name.
        
    .DESCRIPTION
        Derives the Finance and Operations model name from an
        msprov_fnopackage name.
        
        Delete packages use the pattern Model_Delete_*.
        Full packages typically end with _1_0_0_1_managed.zip.
        
    .PARAMETER PackageName
        The msprov_name value from the package row.
        
    .EXAMPLE
        PS C:\> Get-UdePackageModelName -PackageName "ESIntegrationFramework_1_0_0_1_managed.zip"
        
        This will return ESIntegrationFramework.
        
    .EXAMPLE
        PS C:\> Get-UdePackageModelName -PackageName "ESIntegrationFramework_Delete_20260907095029_81ba79b5"
        
        This will return ESIntegrationFramework.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdePackageModelName {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $PackageName
    )

    if ([System.String]::IsNullOrWhiteSpace($PackageName)) { return }

    if ($PackageName -match '^(?<model>.+)_Delete_') {
        return $Matches['model']
    }

    if ($PackageName.EndsWith('_1_0_0_1_managed.zip')) {
        return $PackageName.Substring(0, $PackageName.Length - '_1_0_0_1_managed.zip'.Length)
    }

    if ($PackageName.EndsWith('.zip')) {
        return [System.IO.Path]::GetFileNameWithoutExtension($PackageName)
    }

    $PackageName
}