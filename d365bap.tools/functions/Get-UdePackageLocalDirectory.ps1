
<#
    .SYNOPSIS
        Gets local UDE PackagesLocalDirectory paths

    .DESCRIPTION
        Finds installed package folders under the local Dynamics 365 developer folder

        Returns the full PackagesLocalDirectory path for each match, sorted ascending

    .PARAMETER Version
        Packages version to include. Supports wildcards.

        Default: '*'.

    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file

    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory

        Lists all local PackagesLocalDirectory paths.
        It will only include versions where PackagesLocalDirectory exists.

    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -Version '10.0.2345*'

        Lists matching PackagesLocalDirectory paths. Wildcards are supported.

    .EXAMPLE
        PS C:\> Get-UdePackageLocalDirectory -AsExcelOutput

        Lists all local PackagesLocalDirectory paths into an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdePackageLocalDirectory {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.UdePackageLocalDirectory')]
	param (
		[string] $Version = '*',

		[switch] $AsExcelOutput
	)

	begin {
		$pathPackagesRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Dynamics365'
	}

	process {
		$resCol = @(
			Get-ChildItem -LiteralPath $pathPackagesRoot -Directory |
			Where-Object { $_.Name -match '^\d+(\.\d+)+$' -and $_.Name -like $Version } |
			ForEach-Object {
				$pathPackagesLocal = Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory'
				if (-not (Test-Path -LiteralPath $pathPackagesLocal)) { return }

				$verInfo = Resolve-FinOpsVersionFromCache -Build $_.Name

				[PSCustomObject]@{
					PackagesVersion        = $_.Name
					PackagesLocalDirectory = $pathPackagesLocal
					AppVersion             = if ($null -ne $verInfo) { $verInfo.AppVersion } else { '' }
					AppBuild               = if ($null -ne $verInfo) { $verInfo.AppBuild } else { '' }
					PlatVersion            = if ($null -ne $verInfo) { $verInfo.PlatVersion } else { '' }
					PlatBuild              = if ($null -ne $verInfo) { $verInfo.PlatBuild } else { '' }
				}
			} |
			Sort-Object { [version]$_.PackagesVersion }
		)

		$output = $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.UdePackageLocalDirectory' -Property *

		if ($AsExcelOutput) {
			$output | Export-Excel -WorksheetName "Get-UdePackageLocalDirectory" `
				-NoNumberConversion PackagesVersion, AppVersion, AppBuild, PlatVersion, PlatBuild
			return
		}

		$output
	}

	end {
	}
}
