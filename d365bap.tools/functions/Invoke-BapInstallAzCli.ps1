<#
    .SYNOPSIS
        Installs Azure CLI by downloading the MSI from the official Microsoft URL.
        
    .DESCRIPTION
        This function downloads and installs Azure CLI (az), a command-line tool for managing Azure resources.
        
    .PARAMETER Url
        The URL to download Azure CLI from. Defaults to the official Microsoft URL.
        
    .PARAMETER Quiet
        Install Azure CLI silently (/quiet /norestart). Enabled by default, pass -Quiet:$false for an interactive install.
        
    .EXAMPLE
        PS C:\> Invoke-BapInstallAzCli
        
        This will download and install Azure CLI silently.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-BapInstallAzCli {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType()]
    param (
        [string] $Url = "https://aka.ms/installazurecliwindowsx64",

        [bool] $Quiet = $true
    )

    begin {
        # Suppress progress reporting from Invoke-WebRequest
        # Based on: https://github.com/PowerShell/Microsoft.PowerShell.Archive/issues/77#issuecomment-601947496
        $currentProgress = $global:ProgressPreference
        $global:ProgressPreference = "SilentlyContinue"
    }
    process {
        $msiPath = Join-Path -Path $env:TEMP -ChildPath "AzureCLI.msi"

        Invoke-WebRequest -Uri $Url `
            -OutFile $msiPath `
            -UseBasicParsing `
            -ErrorAction Stop > $null

        if ($null -eq (Get-Item -Path $msiPath -ErrorAction SilentlyContinue)) {
            $messageString = "File download <c='em'>failed</c>. Please make sure that you have internet access and permissions for the specified path '<c='em'>$msiPath</c>'."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because file download failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Unblock-File -Path $msiPath > $null

        $msiArgs = "/i `"$msiPath`""
        if ($Quiet) {
            $msiArgs += " /quiet /norestart"
        }

        $install = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList $msiArgs `
            -Wait `
            -PassThru `
            -ErrorAction Stop

        if ($install.ExitCode -ne 0) {
            $messageString = "Azure CLI installation <c='em'>failed</c> with exit code '<c='em'>$($install.ExitCode)</c>'."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Azure CLI installation failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # msiexec updates the Machine PATH, which the current session does not pick up automatically.
        $env:Path = "$([Environment]::GetEnvironmentVariable('Path', 'Machine'));$([Environment]::GetEnvironmentVariable('Path', 'User'))"

        $msiPath | Remove-Item -Force -ErrorAction SilentlyContinue

        if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
            $messageString = "Azure CLI installation <c='em'>could not be verified</c>. The '<c='em'>az</c>' command was not found on PATH after installation."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Azure CLI was not found after installation." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }

    end {
        $global:ProgressPreference = $currentProgress
    }
}
