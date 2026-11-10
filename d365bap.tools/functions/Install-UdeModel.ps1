<#
    .SYNOPSIS
        Installs UDE models from a package into active metadata.

    .DESCRIPTION
        Installs package modules into active metadata with platform checks.
        Newer modules are skipped and reported while older ones install.

    .PARAMETER Path
        Package zip or directory to install.

    .PARAMETER Force
        Installs newer modules instead of skipping them.

    .PARAMETER AsExcelOutput
        Exports results to Excel instead of returning rows.

    .EXAMPLE
        PS C:\> Install-UdeModel -Path "C:\Temp\Package.zip"

        Installs package modules into active metadata.
        It uses -Path to select the package to install.
        It skips newer modules and installs the rest.

    .EXAMPLE
        PS C:\> Install-UdeModel -Path "C:\Temp\Package" -Force

        Installs all modules including newer ones.
        It uses -Path to select the package to install.
        It uses -Force to install newer modules as well.

    .EXAMPLE
        PS C:\> Install-UdeModel -Path "C:\Temp\Package.zip" -AsExcelOutput

        Installs modules and writes the results to Excel.
        It uses -Path to select the package to install.
        It uses -AsExcelOutput to export the results.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Install-UdeModel {
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	[OutputType('D365Bap.Tools.UdeModelInstall[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path,

		[switch] $Force,

		[switch] $AsExcelOutput
	)

	begin {
		Add-Type -AssemblyName System.IO.Compression.FileSystem
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$objDevenv = Get-Process -Name "devenv" `
			-ErrorAction SilentlyContinue

		if ($objDevenv.Count -gt 0) {
			$messageString = "Visual Studio is running. Exit Visual Studio and run the cmdlet again."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because of running Visual Studio." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		if ($Path.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)) {
			Unblock-File -LiteralPath $Path

			$extractedPath = $Path.Substring(0, $Path.Length - 4)

			if (-not (Test-Path -LiteralPath $extractedPath)) {
				Expand-Archive -Path $Path `
					-DestinationPath $extractedPath
			}

			$Path = $extractedPath
		}

		if (-not ([System.IO.Path]::IsPathRooted($Path))) {
			$objLocation = Get-Location
			$absolutePath = Join-Path -Path $objLocation `
				-ChildPath $Path

			$absolutePath = [System.IO.Path]::GetFullPath($absolutePath)
			Write-PSFMessage -Level Verbose `
				-Message "Updating path to '$absolutePath' as relative paths are not supported"

			$Path = $absolutePath
		}

		if (-not (Test-Path -LiteralPath $Path)) {
			$messageString = "The package path was not found. Verify the path and try again."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the package path was NOT found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		Get-ChildItem -Path $Path `
			-Recurse |

		Unblock-File

		$colConfigs = @(Get-UdeConfig -Active)

		if ($colConfigs.Count -eq 0) {
			$messageString = "No active UDE configuration was found. Activate one and try again."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because no active UDE configuration was found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$objUdeConfig = $colConfigs[0]
		$metadataDir = "$($objUdeConfig.MetadataDirectory)"

		if ([string]::IsNullOrWhiteSpace($metadataDir)) {
			$messageString = "The active UDE configuration has no metadata directory."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the metadata directory is missing." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		if (-not (Test-Path -LiteralPath $metadataDir)) {
			$messageString = "The metadata directory was not found. Verify the configuration."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the metadata directory was NOT found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colConnections = @(Get-UdeConnection)

		if ($colConnections.Count -eq 0) {
			return
		}

		$objUdeConnection = $colConnections[0]

		if (Test-PSFFunctionInterrupt) { return }

		$envObj = Get-Environment -EnvironmentId "*" `
			-Unified `
			-VersionDetails

		$colEnvs = @($envObj)

		$objEnv = $null

		foreach ($itemEnv in $colEnvs) {
			if ($itemEnv.PpacEnvUri -eq $objUdeConnection.PpacEnvUri) {
				$objEnv = $itemEnv
				break
			}
		}

		if ($null -eq $objEnv) {
			$connHost = $null

			try {
				$connHost = ([uri]$objUdeConnection.PpacEnvUri).Host
			}
			catch {
				Write-PSFMessage -Level Verbose `
					-Message "Could not parse the cached connection URI."
			}

			if (-not [string]::IsNullOrWhiteSpace($connHost)) {
				foreach ($itemEnv in $colEnvs) {
					$itemHost = $null

					try {
						$itemHost = ([uri]$itemEnv.PpacEnvUri).Host
					}
					catch {
						Write-PSFMessage -Level Verbose `
							-Message "Could not parse an environment URI."
					}

					if ($itemHost -eq $connHost) {
						$objEnv = $itemEnv
						break
					}
				}
			}
		}

		if ($null -eq $objEnv) {
			$messageString = "The connected environment was not found. Verify the cached connection."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the connected environment was NOT found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$envBuild = "$($objEnv.Build)".Trim()

		if ([string]::IsNullOrWhiteSpace($envBuild)) {
			$envBuild = "$($objEnv.PpacProvApp)".Trim()
		}

		$envPlatform = "$($objEnv.PlatformVersion)".Trim()

		if ([string]::IsNullOrWhiteSpace($envPlatform)) {
			$envPlatform = "$($objEnv.PlatBuild)".Trim()
		}

		if ([string]::IsNullOrWhiteSpace($envPlatform)) {
			$envPlatform = "$($objEnv.PlatVersion)".Trim()
		}

		$aosPath = Join-Path -Path $Path `
			-ChildPath "AOSService"

		$packagesPath = Join-Path -Path $aosPath `
			-ChildPath "Packages"

		$colFilesDirs = @(Get-ChildItem -Path $packagesPath `
				-Directory `
				-Filter "files" `
				-ErrorAction SilentlyContinue)

		if ($colFilesDirs.Count -eq 0) {
			$messageString = "No files folder was found. Ensure the package is extracted correctly."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because of missing files folder." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colZips = @(Get-ChildItem -Path $colFilesDirs[0].FullName `
				-File `
				-Filter "dynamicsax-*.zip" `
				-ErrorAction SilentlyContinue)

		if ($colZips.Count -eq 0) {
			$messageString = "No module zip files were found. Ensure the package is correct."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because of missing module zip files." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colModules = @(
			foreach ($itemZip in $colZips) {
				$modelName = Get-UdeModelSdpModuleName -ZipFileName $itemZip.Name
				$modelPlatform = Get-UdeModelDllPlatformVersion -ZipPath $itemZip.FullName `
					-ModelName $modelName

				[PSCustomObject][ordered]@{
					Model         = $modelName
					ZipPath       = $itemZip.FullName
					ZipName       = $itemZip.Name
					ModelPlatform = $modelPlatform
				}
			}
		)

		$colPreview = @(
			foreach ($itemModule in $colModules) {
				"$($itemModule.Model)"
			}
		)
		$shouldAffected = "$($objUdeConfig.Name) ($($objUdeConfig.MetadataDirectory))"
		$shouldLabel = "Install UDE models into metadata"

		if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { $colPreview; return }

		$colRes = @(
			foreach ($itemModule in $colModules) {
				$modelName = "$($itemModule.Model)"
				$modelPlatform = "$($itemModule.ModelPlatform)"
				$compareState = Get-UdeModelPlatformCompare -ModelPlatform $modelPlatform `
					-EnvPlatform $envPlatform

				if ($compareState -eq "Newer") {
					if (-not $Force) {
						Write-PSFMessage -Level Important `
							-Message "Skipping model with platform newer than the environment."

						[PSCustomObject][ordered]@{
							Model             = $modelName
							Package           = "$($itemModule.ZipName)"
							ModelPlatform     = $modelPlatform
							EnvPlatform       = $envPlatform
							EnvBuild          = $envBuild
							Status            = "SkippedNewer"
							MetadataDirectory = $metadataDir
							ModulePath        = ""
							PSTypeName        = "D365Bap.Tools.UdeModelInstall"
						}

						continue
					}
				}

				if ($compareState -eq "Older") {
					Write-PSFMessage -Level Important `
						-Message "Model platform is older than the environment. Continuing."
				}

				if ($compareState -eq "Unknown") {
					Write-PSFMessage -Level Important `
						-Message "Could not determine the model platform. Continuing."
				}

				if ($compareState -eq "Newer") {
					Write-PSFMessage -Level Important `
						-Message "Model platform is newer. Continuing because Force was supplied."
				}

				$moduleDir = Join-Path -Path $metadataDir `
					-ChildPath $modelName

				try {
					if (Test-Path -LiteralPath $moduleDir) {
						Remove-Item -LiteralPath $moduleDir `
							-Recurse `
							-Force `
							-Confirm:$false

						Write-PSFMessage -Level Verbose `
							-Message "Deleted existing module folder."
					}

					Expand-Archive -Path "$($itemModule.ZipPath)" `
						-DestinationPath $moduleDir `
						-Force

					Write-PSFMessage -Level Verbose `
						-Message "Installed module into metadata."

					[PSCustomObject][ordered]@{
						Model             = $modelName
						Package           = "$($itemModule.ZipName)"
						ModelPlatform     = $modelPlatform
						EnvPlatform       = $envPlatform
						EnvBuild          = $envBuild
						Status            = "Installed"
						MetadataDirectory = $metadataDir
						ModulePath        = $moduleDir
						PSTypeName        = "D365Bap.Tools.UdeModelInstall"
					}
				}
				catch {
					Write-PSFMessage -Level Important `
						-Message "Failed installing model into metadata." `
						-Exception $PSItem.Exception

					[PSCustomObject][ordered]@{
						Model             = $modelName
						Package           = "$($itemModule.ZipName)"
						ModelPlatform     = $modelPlatform
						EnvPlatform       = $envPlatform
						EnvBuild          = $envBuild
						Status            = "Failed"
						MetadataDirectory = $metadataDir
						ModulePath        = $moduleDir
						PSTypeName        = "D365Bap.Tools.UdeModelInstall"
					}
				}
			}
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName "Install-UdeModel" `
				-NoNumberConversion ModelPlatform, EnvPlatform, EnvBuild

			return
		}

		$colRes |
		Select-PSFObject -TypeName "D365Bap.Tools.UdeModelInstall" `
			-Property *
	}

	end {
	}
}

function Get-UdeModelSdpModuleName {
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ZipFileName
	)

	$baseName = [System.IO.Path]::GetFileNameWithoutExtension($ZipFileName)

	if ($baseName -match "^dynamicsax-([A-Za-z0-9_]+)\.(\d+(\.\d+)*)$") {
		$Matches[1]
	}
	elseif ($baseName.StartsWith("dynamicsax-", [System.StringComparison]::OrdinalIgnoreCase)) {
		$baseName.Substring("dynamicsax-".Length)
	}
	else {
		$baseName
	}
}

function Get-UdeModelDllPlatformVersion {
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ZipPath,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ModelName
	)

	$zipObj = $null
	$tempDll = Join-Path -Path ([System.IO.Path]::GetTempPath()) `
		-ChildPath "$([guid]::NewGuid().ToString()).dll"

	$foundVersion = ""

	try {
		$zipObj = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
		$colDlls = @(
			$zipObj.Entries |
			Where-Object { $_.FullName -like "*.dll" }
		)

		if ($colDlls.Count -gt 0) {
			$objDllEntry = $null

			foreach ($itemEntry in $colDlls) {
				if ($itemEntry.Name -eq "$ModelName.dll") {
					$objDllEntry = $itemEntry
					break
				}
			}

			if ($null -eq $objDllEntry) {
				$objDllEntry = $colDlls[0]
			}

			[System.IO.Compression.ZipFileExtensions]::ExtractToFile($objDllEntry, $tempDll, $true)

			$zipObj.Dispose()
			$zipObj = $null
			[GC]::Collect()
			[GC]::WaitForPendingFinalizers()

			try {
				$objFileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($tempDll)

				foreach ($itemCandidate in @($objFileInfo.ProductVersion, $objFileInfo.FileVersion)) {
					if ([string]::IsNullOrWhiteSpace($itemCandidate)) {
						continue
					}

					$objMatch = [regex]::Match("$itemCandidate", "(\d+\.\d+\.\d+(\.\d+)?)")

					if ($objMatch.Success) {
						$foundVersion = $objMatch.Groups[1].Value
						break
					}
				}
			}
			catch {
				Write-PSFMessage -Level Verbose `
					-Message "Could not read the file version."
			}

			if ([string]::IsNullOrWhiteSpace($foundVersion)) {
				try {
					$rawBytes = [System.IO.File]::ReadAllBytes($tempDll)
					$objAsm = [System.Reflection.Assembly]::Load($rawBytes)
					$colAttrs = @(
						$objAsm.GetCustomAttributesData() |
						Where-Object { $_.AttributeType.FullName -like "*Xppc*" }
					)

					if ($colAttrs.Count -gt 0) {
						$objAttrData = $colAttrs[0]

						if ($objAttrData.ConstructorArguments.Count -gt 0) {
							$attrValue = "$($objAttrData.ConstructorArguments[0].Value)"
							$objMatch = [regex]::Match($attrValue, "(\d+\.\d+\.\d+(\.\d+)?)")

							if ($objMatch.Success) {
								$foundVersion = $objMatch.Groups[1].Value
							}
						}
					}
				}
				catch {
					Write-PSFMessage -Level Verbose `
						-Message "Could not read the assembly attribute."
				}
			}

			if ([string]::IsNullOrWhiteSpace($foundVersion)) {
				try {
					$rawText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($tempDll))
					$objMatch = [regex]::Match($rawText, "XppcVersion.{0,80}?(\d+\.\d+\.\d+(\.\d+)?)")

					if ($objMatch.Success) {
						$foundVersion = $objMatch.Groups[1].Value
					}
				}
				catch {
					Write-PSFMessage -Level Verbose `
						-Message "Could not scan the binary text."
				}
			}
		}
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message "Could not read the module zip."
	}
	finally {
		try {
			if (-Not ($null -eq $zipObj)) {
				$zipObj.Dispose()
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Could not dispose the zip."
		}

		[GC]::Collect()
		[GC]::WaitForPendingFinalizers()

		try {
			if ([System.IO.File]::Exists($tempDll)) {
				Remove-Item -LiteralPath $tempDll `
					-Force `
					-ErrorAction SilentlyContinue
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Could not remove the temp file."
		}
	}

	$foundVersion
}

function Get-UdeModelPlatformCompare {
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[string] $ModelPlatform,

		[string] $EnvPlatform
	)

	$result = "Equal"

	if ([string]::IsNullOrWhiteSpace($ModelPlatform)) {
		$result = "Unknown"
	}
	elseif ([string]::IsNullOrWhiteSpace($EnvPlatform)) {
		$result = "Unknown"
	}
	else {
		try {
			$modelVersion = [version]$ModelPlatform
			$envVersion = [version]$EnvPlatform

			if ($modelVersion -gt $envVersion) {
				$result = "Newer"
			}
			elseif ($modelVersion -lt $envVersion) {
				$result = "Older"
			}
			else {
				$result = "Equal"
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Could not compare versions."

			$result = "Unknown"
		}
	}

	$result
}
