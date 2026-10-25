
<#
    .SYNOPSIS
        Gets UDE NuGet packages for a specified environment.
        
    .DESCRIPTION
        This function retrieves the UDE NuGet packages for a specified environment.
        
        Uses the same DeveloperTools service as the Power Platform Tools for Visual Studio extension.
        
        The NuGet packages were previously available from LCS, and are now served from developertools.powerplatform.microsoft.com.

        This function is a compatibility wrapper around Get-PpacFinOpsAsset and will be removed in a future release. Prefer Get-PpacFinOpsAsset directly.
        
    .PARAMETER EnvironmentId
        The ID of the environment that you want to work against.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .PARAMETER Path
        The path to the directory where the NuGet packages will be saved.
        
        Defaults to "C:\Temp\d365bap.tools\UdeNugets".

    .PARAMETER OutputPath
        Custom extraction root for the NuGet packages.

        When specified, overrides the default extraction path under "$env:LOCALAPPDATA\Microsoft\Dynamics365\<build>\NuGets".
        The build version and "NuGets" subfolder are still appended, e.g. -OutputPath "C:\tmp\D365" extracts to "C:\tmp\D365\<build>\NuGets".

        Useful on build agents where the default user profile path is too long for the toolchain.
        
    .PARAMETER Packages
        The types of NuGet packages to retrieve.
        
        Can be one or more of the following values: "All", "CompilerPackage", "Platform", "ApplicationSuite", "Application1", "Application2".
        
        Defaults to "All".
        
    .PARAMETER Download
        Instructs the function to download the NuGet packages to the specified path.
        
    .PARAMETER ClearNugetPackages
        Instructs the function to clear the existing extracted NuGet packages before extracting.
        
        Mapped to the -Force handling of Get-PpacFinOpsAsset: files are re-downloaded and re-extracted.
        
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

    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download -OutputPath "C:\tmp\D365"
        
        This will download the UDE NuGet packages for the specified environment ID to the default path.
        It will extract the NuGet packages to "C:\tmp\D365\<build>\NuGets", avoiding long user profile paths on build agents.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeNuget {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    [Obsolete("Get-UdeNuget is obsolete and will be removed in a future release. Use Get-PpacFinOpsAsset instead.")]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [string] $Path = "C:\Temp\d365bap.tools\UdeNugets",

        [ValidateSet('All', 'CompilerPackage', 'Platform', 'ApplicationSuite', 'Application1', 'Application2')]
        [string[]] $Packages = 'All',

        [switch] $Download,

        [switch] $ClearNugetPackages,

        [string] $OutputPath
    )
    
    begin {
        $packageMap = [ordered]@{
            "CompilerPackage"  = @{ PackageId = "Microsoft.Dynamics.AX.Platform.CompilerPackage"; DisplayName = "Compiler Tools" }
            "Platform"         = @{ PackageId = "Microsoft.Dynamics.AX.Platform.DevALM.BuildXpp"; DisplayName = "Platform Build Reference" }
            "ApplicationSuite" = @{ PackageId = "Microsoft.Dynamics.AX.ApplicationSuite.DevALM.BuildXpp"; DisplayName = "ApplicationSuite Build Reference" }
            "Application1"     = @{ PackageId = "Microsoft.Dynamics.AX.Application1.DevALM.BuildXpp"; DisplayName = "Application 1 Build Reference" }
            "Application2"     = @{ PackageId = "Microsoft.Dynamics.AX.Application2.DevALM.BuildXpp"; DisplayName = "Application 2 Build Reference" }
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

        if ($Packages -eq 'All') {
            $assetNames = @('CompilerPackage', 'Platform', 'ApplicationSuite', 'Application1', 'Application2')
        }
        else {
            $assetNames = @($Packages)
        }

        $assetParams = @{
            Build         = $build
            Asset         = $assetNames
            Kind          = 'NuGet'
            Path          = $Path
            EnvironmentId = $EnvironmentId
        }

        if ($Download) { $assetParams['Download'] = $true }
        if ($ClearNugetPackages) { $assetParams['Force'] = $true }
        if ($PSBoundParameters.ContainsKey('OutputPath')) { $assetParams['OutputPath'] = $OutputPath }

        $colAssets = Get-PpacFinOpsAsset @assetParams

        if (Test-PSFFunctionInterrupt) { return }

        foreach ($assetObj in @($colAssets)) {
            $packageId = $packageMap[$assetObj.Asset].PackageId
            $displayName = $packageMap[$assetObj.Asset].DisplayName
            $packageVersion = $assetObj.FileName.Replace("$packageId.", "").Replace(".nupkg", "")

            $nugetObj = [PsCustomObject][Ordered]@{
                "Package"        = $assetObj.Asset
                "PackageId"      = $packageId
                "DisplayName"    = $displayName
                "Build"          = $assetObj.Build
                "PackageVersion" = $packageVersion
                "Uri"            = $assetObj.Uri
            }

            if ($null -ne $assetObj.Path) {
                $nugetObj | Add-Member -NotePropertyName "Path" -NotePropertyValue $assetObj.Path -Force
            }

            if ($null -ne $assetObj.ExtractedPath) {
                $nugetObj | Add-Member -NotePropertyName "ExtractedPath" -NotePropertyValue $assetObj.ExtractedPath -Force
            }

            $nugetObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeNuget" `
                -Property *
        }
    }

    end {
    }
}