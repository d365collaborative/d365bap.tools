
<#
    .SYNOPSIS
        Gets UDE NuGet packages for a specified environment.
        
    .DESCRIPTION
        This function retrieves the UDE NuGet packages for a specified environment.
        
        Uses the same DeveloperTools service as the Power Platform Tools for Visual Studio extension.
        
        The NuGet packages were previously available from LCS, and are now served from developertools.powerplatform.microsoft.com.
        
    .PARAMETER EnvironmentId
        The ID of the environment that you want to work against.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .PARAMETER Path
        The path to the directory where the NuGet packages will be saved.
        
        Defaults to "C:\Temp\d365bap.tools\UdeNugets".
        
    .PARAMETER Packages
        The types of NuGet packages to retrieve.
        
        Can be one or more of the following values: "All", "CompilerPackage", "Platform", "ApplicationSuite", "Application1", "Application2".
        
        Defaults to "All".
        
    .PARAMETER Download
        Instructs the function to download the NuGet packages to the specified path.
        
    .PARAMETER ClearNugetPackages
        Instructs the function to clear the existing extracted NuGet packages before extracting.
        
        Use with caution as it will delete existing files.
        
        Can be useful when the extraction has failed previously and you want to ensure a clean state for the extraction.
        
    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123"
        
        This will retrieve the UDE NuGet packages for the specified environment ID without downloading them.
        
    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download
        
        This will download the UDE NuGet packages for the specified environment ID to the default path.
        
    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download -Packages "CompilerPackage","Platform"
        
        This will download only the CompilerPackage and Platform UDE NuGet packages for the specified environment ID to the default path.
        
    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download -ClearNugetPackages
        
        This will download the UDE NuGet packages for the specified environment ID to the default path.
        It will clear the existing extracted NuGet packages before extracting, ensuring a clean state for the extraction.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeNuget {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [string] $Path = "C:\Temp\d365bap.tools\UdeNugets",

        [ValidateSet('All', 'CompilerPackage', 'Platform', 'ApplicationSuite', 'Application1', 'Application2')]
        [string[]] $Packages = 'All',

        [switch] $Download,

        [switch] $ClearNugetPackages
    )
    
    begin {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $executable = Get-PSFConfigValue -FullName "d365bap.tools.path.azcopy"

        $packageMap = [ordered]@{
            "CompilerPackage"  = @{ PackageId = "Microsoft.Dynamics.AX.Platform.CompilerPackage"; DisplayName = "Compiler Tools" }
            "Platform"         = @{ PackageId = "Microsoft.Dynamics.AX.Platform.DevALM.BuildXpp"; DisplayName = "Platform Build Reference" }
            "ApplicationSuite" = @{ PackageId = "Microsoft.Dynamics.AX.ApplicationSuite.DevALM.BuildXpp"; DisplayName = "ApplicationSuite Build Reference" }
            "Application1"     = @{ PackageId = "Microsoft.Dynamics.AX.Application1.DevALM.BuildXpp"; DisplayName = "Application 1 Build Reference" }
            "Application2"     = @{ PackageId = "Microsoft.Dynamics.AX.Application2.DevALM.BuildXpp"; DisplayName = "Application 2 Build Reference" }
        }

        $colPackageTypes = @()

        if ($Packages -eq 'All') {
            $colPackageTypes = @($packageMap.Keys)
        }
        else {
            $colPackageTypes = @($Packages)
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $build = $envObj.PpacProvApp
        $buildDashed = $build.Replace(".", "-")

        if ($Download) {
            $downloadDir = "$Path\$build"
            New-Item -Path $downloadDir `
                -ItemType Directory `
                -Force `
                -WarningAction SilentlyContinue > $null
        }

        $baseUri = $envObj.PpacEnvUri + "/" #! Very important to have the trailing slash

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            "Correlationid"           = [guid]::NewGuid().ToString()
            "Dataverseenvironmenturi" = $envObj.PpacEnvUri
            "Authorization"           = "Bearer $($tokenWebApiValue)"
            "Odata-Maxversion"        = "4.0"
            "Odata-Version"           = "4.0"
            "Accept"                  = "application/json"
        }

        $colNugets = @(
            foreach ($package in $colPackageTypes) {
                $packageId = $packageMap[$package].PackageId
                $displayName = $packageMap[$package].DisplayName

                $localUri = "https://developertools.powerplatform.microsoft.com/api/clientmetadata/nugetpackage?packageName=$([uri]::EscapeDataString($packageId))&version=$buildDashed"

                $sasUri = Invoke-RestMethod -Method Get `
                    -Uri $localUri `
                    -Headers $headers

                $uriLeaf = Split-Path $sasUri -Leaf
                $fileName = $uriLeaf.Split("?")[0]
                $packageVersion = $fileName.Replace("$packageId.", "").Replace(".nupkg", "")

                [PsCustomObject][Ordered]@{
                    "Package"        = $package
                    "PackageId"      = $packageId
                    "DisplayName"    = $displayName
                    "Build"          = $build
                    "PackageVersion" = $packageVersion
                    "Uri"            = $sasUri
                } | Select-PSFObject -TypeName "D365Bap.Tools.UdeNuget" `
                    -Property *
            }
        )

        if (-not $Download) {
            $colNugets
            return
        }

        if (-not [System.IO.File]::Exists($executable)) {
            $messageString = "AzCopy executable not found at <c='em'>$executable</c>. Please install AzCopy using <c='em'>Invoke-BapInstallAzCopy</c> or configure the path using <c='em'>Set-BapAzCopyPath</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because AzCopy executable was not found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Write-PSFMessage -Level Important -Message "Will start the download of the NuGet packages:"

        $retryCount = 0
        $maxRetries = 5

        do {
            $retryCount++

            foreach ($nugetObj in $colNugets) {
                $uriQuery = Split-Path $nugetObj.Uri -Leaf
                $fileName = $uriQuery.Split("?")[0]
                $outputPath = Join-Path $downloadDir $fileName

                $nugetObj | Add-Member -NotePropertyName "Path" -NotePropertyValue $outputPath -Force

                if ([System.IO.Path]::Exists($outputPath)) {
                    Write-PSFMessage -Level Important -Message " - Skipping <c='em'>$fileName</c> as it already <c='em'>exists</c>"
                    continue
                }

                Write-PSFMessage -Level Important -Message " - <c='em'>$fileName</c>"

                $azCopyOut = & $executable copy "$($nugetObj.Uri)" "$outputPath" --overwrite=true 2>&1
                Write-PSFMessage -Level Verbose -Message ($azCopyOut -join [Environment]::NewLine)
            }
        } while (
            ($colNugets | `
                Where-Object { -not [System.IO.File]::Exists($_.Path) }) `
                -and $retryCount -lt $maxRetries
        )

        foreach ($nugetObj in $colNugets) {
            if (-not [System.IO.File]::Exists($nugetObj.Path)) {
                Write-PSFMessage -Level Important -Message "File <c='em'>$($nugetObj.Path)</c> does not exist. It seems the download failed."
                Stop-PSFFunction -Message "Stopping because at least one file download failed." `
                    -Exception $([System.Exception]::new("File $($nugetObj.Path) does not exist. Download failed."))
                continue
            }

            Unblock-File -Path $nugetObj.Path
        }

        if (Test-PSFFunctionInterrupt) { return }

        # Extract each .nupkg (a zip) to a version folder next to the PackagesLocalDirectory
        $pathNugetsRoot = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$build\NuGets"

        New-Item -Path $pathNugetsRoot `
            -ItemType Directory `
            -Force `
            -WarningAction SilentlyContinue > $null

        foreach ($nugetObj in $colNugets) {
            $extractDirName = [System.IO.Path]::GetFileNameWithoutExtension($nugetObj.Path)
            $extractPath = Join-Path $pathNugetsRoot $extractDirName

            $nugetObj | Add-Member -NotePropertyName "ExtractedPath" -NotePropertyValue $extractPath -Force

            if ([System.IO.Path]::Exists($extractPath)) {
                if (-not $ClearNugetPackages) {
                    Write-PSFMessage -Level Important -Message "The extracted folder for <c='em'>$extractDirName</c> already exists. If you want to re-extract, please run this command again with the switch <c='em'>-ClearNugetPackages</c>."
                    continue
                }

                Remove-Item -Path $extractPath -Recurse -Force
            }

            Write-PSFMessage -Level Important -Message "Will extract <c='em'>$extractDirName</c>..."
            [IO.Compression.ZipFile]::ExtractToDirectory($nugetObj.Path, $extractPath, $true)
            Write-PSFMessage -Level Important -Message "Extraction of <c='em'>$extractDirName</c> completed..."
        }

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()

        $colNugets
    }

    end {
    }
}
