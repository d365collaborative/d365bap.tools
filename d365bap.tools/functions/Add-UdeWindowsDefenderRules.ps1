
<#
    .SYNOPSIS
        Adds Windows Defender exclusion rules for UDE development tools and environments.
        
    .DESCRIPTION
        This function configures Windows Defender by adding exclusion rules for processes, paths, and file extensions commonly used in UDE development environments.
        
        This helps to prevent Windows Defender from interfering with development activities.
        
    .PARAMETER Force
        Instructs the function to run with elevated (Administrator) privileges. If the current PowerShell session is not running as Administrator, the function will restart PowerShell with elevated privileges.
        
    .EXAMPLE
        PS C:\> Add-UdeWindowsDefenderRules
        
        This command adds the necessary Windows Defender exclusion rules for UDE development.
        If the current session is not running as Administrator, it will fail.
        
    .EXAMPLE
        PS C:\> Add-UdeWindowsDefenderRules -Force
        
        This command adds the necessary Windows Defender exclusion rules for UDE development.
        If the current session is not running as Administrator, it will restart PowerShell with elevated privileges.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-UdeWindowsDefenderRules {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    param (
        [switch] $Force
    )

    $defenderOptions = Get-MpComputerStatus

    $DefenderEnabled = $true -eq $defenderOptions.AntivirusEnabled

    if ($DefenderEnabled -eq $false) {
        $messageString = "Windows Defender is <c='em'>NOT</c> enabled on this machine."
        Write-PSFMessage -Level Host -Message $messageString
        Stop-PSFFunction -Message "Stopping because Windows Defender is turned off." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        return
    }

    if ($Force -and (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit", "-Command", "cd '$pwd'; Import-Module d365bap.tools; Add-UdeWindowsDefenderRules -Force"
        exit
    }

    if ((-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        $messageString = "The current PowerShell session is <c='em'>NOT</c> running with elevated (Administrator) privileges. Please run this function with the <c='em'>-Force</c> or start a new PowerShell session as Administrator."
        Write-PSFMessage -Level Host -Message $messageString
        Stop-PSFFunction -Message "Stopping because Windows Defender is turned off." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        return
    }

    try {
        # visual studio & tools
        Add-MpPreference -ExclusionProcess "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"

        # Safest way to detect VS 2022 installation is via WMI
        $wmiObj = Get-CimInstance -ClassName MSFT_VSInstance `
            -Namespace root/cimv2/vs | `
            Where-Object { $_.Name -like "Visual Studio*2022" }

        Add-MpPreference -ExclusionProcess "$($wmiObj.InstallLocation)\Common7\IDE\devenv.exe"
        Add-MpPreference -ExclusionProcess "$($wmiObj.InstallLocation)\Common7\IDE\qtagent32_40.exe"
        Add-MpPreference -ExclusionProcess "$($wmiObj.InstallLocation)\Common7\IDE\Extensions\TestPlatform\testhost.exe"
        Add-MpPreference -ExclusionProcess "$($wmiObj.InstallLocation)\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
        
        Add-MpPreference -ExclusionProcess "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
        Add-MpPreference -ExclusionProcess "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
        Add-MpPreference -ExclusionProcess "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe"
        Add-MpPreference -ExclusionProcess "C:\Program Files\dotnet\dotnet.exe"

        Add-MpPreference -ExclusionProcess $(Get-PSFConfigValue -FullName "d365bap.tools.path.azcopy")
        
        # Dynamics 365 Finance and Operations
        foreach ($filePath in (Get-Item -Path "$Env:USERPROFILE\AppData\Local\Microsoft\Dynamics365\*\PackagesLocalDirectory\bin\*.exe" | Select-Object -ExpandProperty FullName)) {
            Add-MpPreference -ExclusionProcess "$filePath"
        }
        
        # add SQLServer
        Add-MpPreference -ExclusionProcess "C:\Program Files\Microsoft SQL Server\150\LocalDB\Binn\sqlservr.exe"

        # add IIS and IISExpress
        Add-MpPreference -ExclusionProcess "C:\Windows\System32\inetsrv\w3wp.exe"
        Add-MpPreference -ExclusionProcess "C:\Program Files\IIS Express\iisexpress.exe"

        # add Git
        Add-MpPreference -ExclusionProcess "C:\Program Files\Git\cmd\git.exe"

        # cache folders
        Add-MpPreference -ExclusionPath "C:\Program Files (x86)\Microsoft Visual Studio"
        Add-MpPreference -ExclusionPath "C:\Program Files\Microsoft Visual Studio"
        Add-MpPreference -ExclusionPath "C:\Windows\assembly"
        Add-MpPreference -ExclusionPath "C:\Windows\Microsoft.NET"
        Add-MpPreference -ExclusionPath "C:\Program Files (x86)\MSBuild"
        Add-MpPreference -ExclusionPath "C:\Program Files\dotnet"
        Add-MpPreference -ExclusionPath "C:\Program Files (x86)\Microsoft SDKs"
        Add-MpPreference -ExclusionPath "C:\Program Files\Microsoft SDKs"
        Add-MpPreference -ExclusionPath "C:\Program Files (x86)\Common Files\Microsoft Shared\MSEnv"
        
        # Trick to get the exclusion path to work
        Add-MpPreference -ExclusionPath $([System.Text.Encoding]::UTF8.GetString(([Convert]::FromBase64String("QzpcUHJvZ3JhbURhdGFcTWljcm9zb2Z0XFZpc3VhbFN0dWRpb1xQYWNrYWdlcw=="))))

        Add-MpPreference -ExclusionPath "C:\Program Files (x86)\Microsoft SDKs\NuGetPackages"
        Add-MpPreference -ExclusionPath "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files"
        Add-MpPreference -ExclusionPath "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
        
        Add-MpPreference -ExclusionPath "C:\Temp\d365bap.tools"

        Add-MpPreference -ExclusionPath "$Env:USERPROFILE\AppData\Local\Microsoft\Dynamics365"
        Add-MpPreference -ExclusionPath "$Env:USERPROFILE\AppData\Roaming\Microsoft\CRMDeveloperToolKit"

        Add-MpPreference -ExclusionPath "$Env:USERPROFILE\AppData\Local\Microsoft\VisualStudio"
        Add-MpPreference -ExclusionPath "$Env:USERPROFILE\AppData\Local\Microsoft\WebsiteCache"
        Add-MpPreference -ExclusionPath "$Env:USERPROFILE\AppData\Roaming\Microsoft\VisualStudio"

        # Extensions
        Add-MpPreference -ExclusionExtension "md"
        Add-MpPreference -ExclusionExtension "man"
        Add-MpPreference -ExclusionExtension "xml"
        Add-MpPreference -ExclusionExtension "xpp"
        Add-MpPreference -ExclusionExtension "netmodule"
    }
    catch {
        Write-PSFMessage -Level Host -Message "Something went wrong while configuring Windows Defender rules." -Exception $PSItem.Exception
        Stop-PSFFunction -Message "Stopping because of errors"
        return
    }
}