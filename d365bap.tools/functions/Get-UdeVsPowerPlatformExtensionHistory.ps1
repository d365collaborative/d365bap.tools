<#
.SYNOPSIS
Get UDE VS Power Platform extension history.

.DESCRIPTION
Gets the UDE VS Power Platform extension history from the local logs folder.

.PARAMETER All
Instructs the cmdlet to return all extension history entries.

.PARAMETER OpenFolder
Instructs the cmdlet to open the folder containing the extension history logs.

.PARAMETER DeploysOnly
Instructs the cmdlet to return only extension history entries related to deployments.

.EXAMPLE
PS C:\> Get-UdeVsPowerPlatformExtensionHistory

This will retrieve the latest UDE VS Power Platform extension history entry from the local logs folder.

.EXAMPLE
PS C:\> Get-UdeVsPowerPlatformExtensionHistory -All

This will retrieve all UDE VS Power Platform extension history entries from the local logs folder.

.EXAMPLE
PS C:\> Get-UdeVsPowerPlatformExtensionHistory -OpenFolder

This will open the folder containing the UDE VS Power Platform extension history logs in File Explorer.

.EXAMPLE
PS C:\> Get-UdeVsPowerPlatformExtensionHistory -DeploysOnly

This will retrieve only UDE VS Power Platform extension history entries related to deployments from the local logs folder.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeVsPowerPlatformExtensionHistory {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $All,

        [switch] $OpenFolder,

        [switch] $DeploysOnly
    )

    begin {
    }
    
    process {
        $path = "$env:LOCALAPPDATA\Microsoft\Dynamics365\Logs"
        
        if ($OpenFolder) {
            Start-Process $path
        }

        $files = Get-ChildItem -Path "$path\*.log" | Sort-Object LastWriteTime -Descending

        $resCol = @(
            foreach ($file in $files) {
                $file | Select-PSFObject -TypeName "D365Bap.Tools.VsPpacExtensionHistory" `
                    -Property @{ Label = "Id"; Expression = { ($_.Name -split "_")[1] } },
                @{ Label = "Deployment"; Expression = { (Get-Content -Path $_.FullName -Raw) -match "Beginning creation of package" } },
                "Length as Size to PSFSize",
                "LastWriteTime as LastModified",
                *
            }
        )

        if ($DeploysOnly) {
            $resCol = $resCol | Where-Object { $_.Deployment -eq $true }
        }

        if (-not $All) {
            $resCol = $resCol | Select-Object -First 1
        }

        $resCol
    }
    
    end {
    }
}