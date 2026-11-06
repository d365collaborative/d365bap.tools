<#
    .SYNOPSIS
        Gets local UDE PackagesLocalDirectory paths

    .DESCRIPTION
        Finds installed package folders under the local Dynamics 365 developer folder. Returns each PackagesLocalDirectory path, sorted ascending, with AppVersion from the cached FinOps catalog. Newer unknown builds show Prerelease.

    .PARAMETER Version
        Packages version to include. Supports wildcards.

        Default: '*'.

    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file

    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory

        Lists all local PackagesLocalDirectory paths.
        It will use the default -Version '*' for installed versions.
        It will include only versions where PackagesLocalDirectory exists.

    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -Version '10.0.2345*'

        Lists matching PackagesLocalDirectory paths.
        It will use -Version '10.0.2345*' to filter the installed versions.
        It will support wildcards in -Version.

    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -AsExcelOutput

        Lists all local PackagesLocalDirectory paths into an Excel file.
        It will use the default -Version '*' for the local versions.
        It will use -AsExcelOutput to write the result to an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdePackageLocalDirectory {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.UdePackageLocalDirectory[]')]
	param (
		[SupportsWildcards()]
		[string] $Version = '*',

		[switch] $AsExcelOutput
	)

	begin {
		$pathPackagesRoot = Join-Path -Path $env:LOCALAPPDATA `
			-ChildPath 'Microsoft\Dynamics365'
	}

	process {
		$colRes = @(
			Get-ChildItem -LiteralPath $pathPackagesRoot `
				-Directory |
			Where-Object {
				($_.Name -match '^\d+(\.\d+)+$') `
					-and ($_.Name -like $Version)
			} | ForEach-Object {
				$pathPackagesLocal = Join-Path -Path $_.FullName `
					-ChildPath 'PackagesLocalDirectory'

				if (-not (Test-Path -LiteralPath $pathPackagesLocal)) { return }

				$tmpVerInfo = Resolve-FinOpsVersionFromCache `
					-Build $_.Name `
					-IgnoreStamp `
					-IncludePrerelease

				[pscustomobject][ordered]@{
					PackagesVersion        = $_.Name
					PackagesLocalDirectory = $pathPackagesLocal
					AppVersion             = ($null -eq $tmpVerInfo) ? '' : $tmpVerInfo.AppVersion
					AppBuild               = ($null -eq $tmpVerInfo) ? '' : $tmpVerInfo.AppBuild
					PlatVersion            = ($null -eq $tmpVerInfo) ? '' : $tmpVerInfo.PlatVersion
					PlatBuild              = ($null -eq $tmpVerInfo) ? '' : $tmpVerInfo.PlatBuild
				}
			} | Sort-Object { [version]$_.PackagesVersion }
		)

		$colOutput = $colRes |
		Select-PSFObject `
			-TypeName 'D365Bap.Tools.UdePackageLocalDirectory' `
			-Property *

		if ($AsExcelOutput) {
			$colOutput |
			Export-Excel `
				-WorksheetName "Get-UdePackageLocalDirectory" `
				-NoNumberConversion PackagesVersion, AppVersion, AppBuild, PlatVersion, PlatBuild

			return
		}

		$colOutput
	}

	end {
	}
}
