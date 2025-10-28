<#
.SYNOPSIS
Installs AzCopy by downloading it from the official Microsoft URL.

.DESCRIPTION
This function downloads and installs AzCopy, a command-line tool for copying data to and from Azure storage.

.PARAMETER Url
The URL to download AzCopy from. Defaults to the official Microsoft URL.

.PARAMETER Path
The local path where AzCopy will be installed.

Defaults to "C:\temp\d365bap.tools\AzCopy\AzCopy.exe".

.EXAMPLE
PS C:\> Invoke-BapInstallAzCopy

This will download and install AzCopy to the default path.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Invoke-BapInstallAzCopy {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType()]
    param (
        [string] $Url = "https://aka.ms/downloadazcopy-v10-windows",

        [string] $Path = "C:\temp\d365bap.tools\AzCopy\AzCopy.exe"
    )

    begin {
        # Suppress progress reporting from Invoke-WebRequest and Expand-Archive
        # Based on: https://github.com/PowerShell/Microsoft.PowerShell.Archive/issues/77#issuecomment-601947496
        $currentProgress = $global:ProgressPreference
        $global:ProgressPreference = "SilentlyContinue"
    }
    process {
        $azCopyFolder = Split-Path $Path -Parent
        $downloadPath = Join-Path -Path $azCopyFolder -ChildPath "AzCopy.zip"

        New-Item -Path $azCopyFolder `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null
        
        Invoke-WebRequest -Uri $Url `
            -OutFile $downloadPath `
            -UseBasicParsing `
            -ErrorAction Stop > $null

        if ($null -eq (Get-Item -Path $downloadPath)) {
            $messageString = "File download <c='em'>failed</c>. Please make sure that you have internet access and permissions for the specified path '<c='em'>$downloadPath</c>'."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because file download failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Unblock-File -Path $downloadPath > $null

        $tempExtractPath = Join-Path -Path $azCopyFolder -ChildPath "Temp"

        Expand-Archive -Path $downloadPath `
            -DestinationPath $tempExtractPath `
            -Force

        $null = (Get-Item "$tempExtractPath\*\azcopy.exe").CopyTo($Path, $true)

        $tempExtractPath | Remove-Item -Force -Recurse
        $downloadPath | Remove-Item -Force -Recurse

        Set-BapAzCopyPath -Path $Path
    }

    end {
        $global:ProgressPreference = $currentProgress
    }
}