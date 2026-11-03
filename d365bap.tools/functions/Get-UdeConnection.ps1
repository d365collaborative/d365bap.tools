<#
    .SYNOPSIS
        Retrieves the UDE connection information.

    .DESCRIPTION
        This function retrieves the connection information that is currently used by Visual Studio for the User Development Environment (UDE).

    .PARAMETER Path
        The path to the UDE configuration folder.

        Default: $env:APPDATA\Microsoft\CRMDeveloperToolKit

    .PARAMETER AsExcelOutput
        Outputs all details to an Excel file, including hidden properties.

    .EXAMPLE
        PS C:\> Get-UdeConnection

        Retrieves the UDE connection information.
        It uses the default -Path $env:APPDATA\Microsoft\CRMDeveloperToolKit.
        It does not use -AsExcelOutput, so results go to the console.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeConnection {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.UdeConnection[]')]
	param (
		[string] $Path = "$env:APPDATA\Microsoft\CRMDeveloperToolKit",

		[switch] $AsExcelOutput
	)

	begin {
		$objConfig = Get-ChildItem `
			-Path "$Path\*.config" `
			-ErrorAction SilentlyContinue |
		Select-Object -First 1 `
			-ExpandProperty FullName

		if ($null -eq $objConfig) {
			$messageString = "The configuration file was not found. This usually means that the CRMDeveloperToolKit has been <c='em'>wiped</c> using <c='em'>Clear-UdeCredentialCache -Force</c>. Please connect to an environment using the <c='em'>Tools -> Connect to Dataverse...</c> in Visual Studio to recreate the configuration file, and then run this command again."

			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the configuration file was not found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		[xml]$xmlConfig = Get-Content -Path $objConfig

		$hashProps = @{}
		foreach ($itemAdd in $($xmlConfig.configuration.appSettings.add)) {
			$hashProps[$itemAdd.key] = $itemAdd.value
		}

		$resCol = [PSCustomObject]$hashProps |
		Select-PSFObject -TypeName 'D365Bap.Tools.UdeConnection' `
			"UserId as Upn",
		@{Name = "ConnectionUri"; Expression = {
				$temp = [uri]$_.DirectConnectionUri;
				$temp.Scheme + "://" + $temp.Host
			}
		},
		@{Name = "PpacEnvUri"; Expression = {
				$temp = [uri]$_.DirectConnectionUri;
				($temp.Scheme + "://" + $temp.Host).Replace("api.", "")
			}
		},
		*

		if ($AsExcelOutput) {
			$resCol |
			Export-Excel -WorksheetName "UdeConnection"
			return
		}

		$resCol
	}

	end {
	}
}
