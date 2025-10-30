
<#
    .SYNOPSIS
        Confirms the installation of Visual Studio 2022.
        
    .DESCRIPTION
        Checks if Visual Studio 2022 is installed on the machine and if the required components are present.
        
        Will prepare necessary files to assist in installing missing components.
        
    .PARAMETER Path
        The path to the directory where prerequisite files will be stored.
        
        Defaults to "C:\Temp\d365bap.tools\Vs2022-Ude-Prerequisites".
        
    .PARAMETER Latest
        Instructs the function to use the latest configuration files from the internet instead of the bundled ones.
        
    .EXAMPLE
        PS C:\> Confirm-UdeVs2022Installation
        
        This command checks for the installation of Visual Studio 2022 and prepares prerequisite files in the default path.
        Will use the bundled configuration files.
        
    .EXAMPLE
        PS C:\> Confirm-UdeVs2022Installation -Latest
        
        This command checks for the installation of Visual Studio 2022 and prepares prerequisite files in the default path.
        Will download the latest configuration files from the internet.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Confirm-UdeVs2022Installation {
    [CmdletBinding()]
    param (
        [string] $Path = 'C:\Temp\d365bap.tools\Vs2022-Ude-Prerequisites',

        [switch] $Latest
    )

    begin {
        # Safest way to detect VS 2022 installation is via WMI
        $wmiObj = Get-CimInstance -ClassName MSFT_VSInstance `
            -Namespace root/cimv2/vs | `
            Where-Object { $_.Name -like "Visual Studio*2022" }

        if ($null -eq $wmiObj) {
            $messageString = "Visual Studio 2022 Professional or Enterprise does not appear to be installed on this machine. Please install Visual Studio 2022 Professional or Enterprise with the required workloads and try again."
            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because Visual Studio 2022 was NOT installed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        # Path for VS_Installer.exe
        $pathVsInstaller = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe"

        # Sub paths for extensions
        $pathExtSuffix = "\Extensions\*\*.vsixmanifest"
        $pathCommonExtSuffix = "\CommonExtensions\Microsoft\*\*.vsixmanifest"

        # Paths to extensions
        $pathVs2022Ext = $wmiObj.ProductLocation.Replace("devenv.exe", $pathExtSuffix)
        $pathVs2022CommonExt = $wmiObj.ProductLocation.Replace("devenv.exe", $pathCommonExtSuffix)
        
        New-Item -Path $Path `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null

        if (-not [System.IO.Path]::Exists("$Path\Vs2022.Extensions.json")) {
            if (-not $Latest) {
                Copy-Item -Path "$script:ModuleRoot\internal\misc\Vs2022.Extensions.json" `
                    -Destination "$Path\Vs2022.Extensions.json" `
                    -Force
            }
            else {
                <# Action when all if and elseif conditions are false #>
            }
        }

        if (-not [System.IO.Path]::Exists("$Path\Full-Ude.vsconfig")) {
            if (-not $Latest) {
                Copy-Item -Path "$script:ModuleRoot\internal\misc\Full-Ude.vsconfig" `
                    -Destination "$Path\Full-Ude.vsconfig" `
                    -Force
            }
            else {
                <# Action when all if and elseif conditions are false #>
            }
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        Write-PSFMessage -Level Host -Message "Starting the <c='em'>Visual Studio Installer</c>:" -Target Host
        Write-PSFMessage -Level Host -Message " - You will need to click <c='em'>Modify</c> or <c='em'>Close</c> when prompted." -Target Host
        Write-PSFMessage -Level Host -Message " - When the installation is finished, you will need to <c='em'>Close</c> the <c='em'>Visual Studio Installer</c> window." -Target Host

        # We need to make sure VS 2022 has the basic workloads installed
        Start-Process -FilePath $pathVsInstaller `
            -ArgumentList "modify --config `"$Path\Full-Ude.vsconfig`" --installPath `"$($wmiObj.InstallLocation)`"" `
            -Wait

        # List of extensions to validate against
        $colExt = (Get-Content "$Path\Vs2022.Extensions.json") | ConvertFrom-Json

        $colManifests = @(Get-Item -Path $pathVs2022Ext | Select-Object -ExpandProperty FullName)
        $colManifests += @(Get-Item -Path $pathVs2022CommonExt | Select-Object -ExpandProperty FullName)

        # Create hashtable of installed extensions
        $hashExtInstalled = @{}
        foreach ($pathManifest in $colManifests) {
            [xml]$xmlMani = Get-Content -Path $pathManifest -Raw

            if ($null -eq $xmlMani.PackageManifest.Metadata.Identity.Id) { continue }

            $hashExtInstalled[$($xmlMani.PackageManifest.Metadata.Identity.Id)] = [ordered]@{
                Id      = $xmlMani.PackageManifest.Metadata.Identity.Id
                Name    = $xmlMani.PackageManifest.Metadata.DisplayName
                Version = $xmlMani.PackageManifest.Metadata.Identity.Version
            }
        }

        # Download missing extensions
        foreach ($ext in $colExt | Where-Object VsixUrl -ne $null) {
            if ($null -ne $hashExtInstalled[$ext.Id]) {
                continue
            }

            Write-PSFMessage -Level Host -Message "Extension: '<c='em'>$($ext.Name)</c>' is missing." -Target Host

            Write-PSFMessage -Level Host -Message " - <c='em'>Downloading</c>..." -Target Host
            
            $file = (Split-Path -Path $ext.Uri -Leaf).Split('.') | Select-Object -Last 1
            Invoke-WebRequest -Uri $ext.VsixUrl `
                -OutFile "$Path\$file.vsix" `
                -UseBasicParsing `
                -ErrorAction Stop > $null

            Write-PSFMessage -Level Host -Message " - <c='em'>Installing</c> - Please make sure to let the VSIX installer finish..." -Target Host

            Start-Process -FilePath "$Path\$file.vsix" `
                -Wait
        }
    }
}