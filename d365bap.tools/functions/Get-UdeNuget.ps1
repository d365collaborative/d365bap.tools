
<#
    .SYNOPSIS
        Gets UDE NuGet packages for a specified environment.

    .DESCRIPTION
        Retrieves UDE NuGet files for an environment via the DeveloperTools service.

        Compatibility wrapper around Get-PpacFinOpsAsset; prefer that command.

    .PARAMETER EnvironmentId
        Environment name, GUID, or wildcard pattern to work against.

    .PARAMETER Path
        Folder where the NuGet files are downloaded.

        Default: C:\Temp\d365bap.tools\UdeNugets

    .PARAMETER OutputPath
        Custom extraction root. Build and NuGets folders are appended.

    .PARAMETER Packages
        Types to retrieve. All selects every package.

        Default: All

    .PARAMETER Download
        Instructs the function to download the NuGet packages to the specified path.

    .PARAMETER ClearNugetPackages
        Re-download and re-extract packages via Get-PpacFinOpsAsset -Force.

    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123"

        This will retrieve the UDE NuGet packages for the specified environment ID without downloading them.

    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download

        This will download the UDE NuGet packages for the specified environment ID to the default path.

    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download -Packages "CompilerPackage","Platform"

        Downloads only CompilerPackage and Platform.

    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download -ClearNugetPackages

        Downloads and re-extracts everything.

    .EXAMPLE
        PS C:\> Get-UdeNuget -EnvironmentId "env-123" -Download -OutputPath "C:\tmp\D365"

        Downloads and extracts under C:\tmp\D365.

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
