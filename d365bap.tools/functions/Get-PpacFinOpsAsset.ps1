<#
    .SYNOPSIS
        Downloads FinOps assets for any build.

    .DESCRIPTION
        Resolves and downloads NuGet packages, developer files and VHD images. Any published version can be selected.

    .PARAMETER Build
        Full build, track or application version to download.

    .PARAMETER Asset
        Names to download; "*" selects everything including VHD.

        Default: "*".

    .PARAMETER Kind
        Kind to keep: NuGet, DeveloperFile or Vhd.

        Default: "*".

    .PARAMETER Download
        Download the files instead of only resolving URLs.

    .PARAMETER Path
        Target folder with a subfolder per build.

        Default: C:\Temp\d365bap.tools\PpacFinOpsAssets

    .PARAMETER OutputPath
        Custom extraction root. Overrides the default under "$env:LOCALAPPDATA\Microsoft\Dynamics365\<build>".

        The build version plus "NuGets" / "PackagesLocalDirectory" subfolders are still appended, e.g. -OutputPath "C:\tmp\D365" extracts to "C:\tmp\D365\<build>\NuGets".

        Useful on build agents where the default user profile path is too long for the toolchain.

    .PARAMETER Force
        Re-download files and re-extract folders.

    .PARAMETER EnvironmentId
        Environment for the auth context only. Omitted: first FinOps environment is used.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46"

        Resolves download URLs for that build.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsBuild -Latest | Get-PpacFinOpsAsset -Kind NuGet -Download

        Downloads all NuGet packages of the newest build.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.49" -Kind DeveloperFile | Where-Object Asset -eq 'SystemMetadata' | Get-PpacFinOpsAsset -Download

        Downloads the system metadata of that track.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46" -Asset Vhd -Download

        Downloads the VHD image parts.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46" -Kind NuGet -Download -OutputPath "C:\tmp\D365"

        Downloads the NuGet packages and extracts them to "C:\tmp\D365\<build>\NuGets", avoiding long user profile paths on build agents.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsAsset {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string] $Build,

		[ValidateSet('*', 'CompilerPackage', 'Platform', 'ApplicationSuite', 'Application1', 'Application2', 'SystemMetadata', 'FinOpsVsix22', 'TraceParser', 'CrossReference', 'Vhd')]
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string[]] $Asset = '*',

		[ValidateSet('*', 'NuGet', 'DeveloperFile', 'Vhd')]
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string] $Kind = '*',

		[switch] $Download,

		[string] $Path = "C:\Temp\d365bap.tools\PpacFinOpsAssets",

		[switch] $Force,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[string] $OutputPath
	)

	begin {
		Add-Type -AssemblyName System.IO.Compression.FileSystem

		$executable = Get-PSFConfigValue -FullName "d365bap.tools.path.azcopy"

		$nugetMap = [ordered]@{
			"CompilerPackage"  = "Microsoft.Dynamics.AX.Platform.CompilerPackage"
			"Platform"         = "Microsoft.Dynamics.AX.Platform.DevALM.BuildXpp"
			"ApplicationSuite" = "Microsoft.Dynamics.AX.ApplicationSuite.DevALM.BuildXpp"
			"Application1"     = "Microsoft.Dynamics.AX.Application1.DevALM.BuildXpp"
			"Application2"     = "Microsoft.Dynamics.AX.Application2.DevALM.BuildXpp"
		}

		$fileEndpoints = [ordered]@{
			"SystemMetadata" = "systemmetadata"
			"FinOpsVsix22"   = "finopsvsix22"
			"TraceParser"    = "traceparser"
			"CrossReference" = "crossreference"
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$ctx = Get-DevToolsAuthContext -EnvironmentId $EnvironmentId

		if ($null -eq $ctx) { return }

		$headers = @{
			"Correlationid"           = [guid]::NewGuid().ToString()
			"Dataverseenvironmenturi" = $ctx.Env.PpacEnvUri
			"Authorization"           = "Bearer $($ctx.Token)"
			"Odata-Maxversion"        = "4.0"
			"Odata-Version"           = "4.0"
			"Accept"                  = "application/json"
		}

		try {
			$catalog = Invoke-RestMethod -Method Get `
				-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
				-Headers $headers
		}
		catch {
			$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
			Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
			Stop-PSFFunction -Message "Stopping because the finopsversions request failed." -ErrorRecord $_
			return
		}

		$fullBuild = $null
		$track = $null
		$trackAppVersion = $null

		if ([string]::IsNullOrWhiteSpace($Build)) {
			$entry = @($catalog | Sort-Object -Property { [version]$_.appVersion } | Select-Object -Last 1)

			if ($null -eq $entry -or $entry.Count -eq 0) {
				Stop-PSFFunction -Message "Stopping because the version catalog is empty."
				return
			}

			$track = $entry[0].appBuild
			$trackAppVersion = $entry[0].appVersion

			try {
				$trackBuilds = Invoke-RestMethod -Method Get `
					-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version=$($track.Replace('.', '-'))" `
					-Headers $headers
			}
			catch {
				$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
				Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
				Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." -ErrorRecord $_
				return
			}

			$fullBuild = @($trackBuilds | Sort-Object -Property { [version]$_ } -Descending | Select-Object -First 1)

			if ([string]::IsNullOrWhiteSpace("$fullBuild")) {
				Stop-PSFFunction -Message "Stopping because no builds were found for track $track."
				return
			}

			$fullBuild = "$fullBuild"
		}
		else {
			$normalized = "$Build".Replace("-", ".").Trim()
			$parts = @($normalized -split "\.")

			if ($parts.Count -eq 4) {
				$fullBuild = $normalized
				$track = "$($parts[0]).$($parts[1]).$($parts[2])"
				$byBuild = @($catalog | Where-Object { $_.appBuild -eq $track } | Select-Object -First 1)

				if ($byBuild.Count -gt 0) {
					$trackAppVersion = $byBuild[0].appVersion
				}
			}
			else {
				$byAppVersion = @($catalog | Where-Object { $_.appVersion -eq $normalized } | Select-Object -First 1)

				if ($byAppVersion.Count -gt 0) {
					$track = $byAppVersion[0].appBuild
					$trackAppVersion = $byAppVersion[0].appVersion
				}
				else {
					$byBuild = @($catalog | Where-Object { $_.appBuild -eq $normalized } | Select-Object -First 1)

					if ($byBuild.Count -gt 0) {
						$track = $byBuild[0].appBuild
						$trackAppVersion = $byBuild[0].appVersion
					}
				}

				if ([string]::IsNullOrWhiteSpace($track)) {
					$valid = ($catalog | Sort-Object -Property { [version]$_.appVersion } | ForEach-Object { $_.appVersion }) -join ", "
					$messageString = "Unknown build or track <c='em'>$Build</c>. Valid application versions are: $valid."
					Write-PSFMessage -Level Important -Message $messageString
					Stop-PSFFunction -Message "Stopping because the build was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
					return
				}

				try {
					$trackBuilds = Invoke-RestMethod -Method Get `
						-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version=$($track.Replace('.', '-'))" `
						-Headers $headers
				}
				catch {
					$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
					Write-PSFMessage -Level Important -Message $messageString -ErrorRecord $_
					Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." -ErrorRecord $_
					return
				}

				$fullBuild = @($trackBuilds | Sort-Object -Property { [version]$_ } -Descending | Select-Object -First 1)

				if ([string]::IsNullOrWhiteSpace("$fullBuild")) {
					Stop-PSFFunction -Message "Stopping because no builds were found for track $track."
					return
				}

				$fullBuild = "$fullBuild"
			}
		}

		$wanted = @()
		$assetExplicit = $PSBoundParameters.ContainsKey('Asset')

		if (-not $assetExplicit) {
			$wanted = @($nugetMap.Keys) + @($fileEndpoints.Keys)
		}
		else {
			foreach ($name in @($Asset)) {
				if ($name -eq '*') {
					$wanted += @($nugetMap.Keys) + @($fileEndpoints.Keys) + @('Vhd')
				}
				else {
					$wanted += $name
				}
			}

			$wanted = @($wanted | Sort-Object -Unique)
		}

		if (-not $assetExplicit -and $PSBoundParameters.ContainsKey('Kind') -and $Kind -ne '*' -and ('Vhd' -like $Kind) -and 'Vhd' -notin $wanted) {
			$wanted += 'Vhd'
		}

		if ($Kind -ne '*') {
			$kindOf = {
				param ([string] $Name)

				if ($Name -eq 'Vhd') { return 'Vhd' }
				if ($nugetMap.Contains($Name)) { return 'NuGet' }

				return 'DeveloperFile'
			}

			$wanted = @($wanted | Where-Object { (& $kindOf $_) -like $Kind })

			if ($wanted.Count -eq 0) {
				Write-PSFMessage -Level Important -Message "No assets match <c='em'>$($Asset -join ', ')</c> filtered by kind <c='em'>$Kind</c>. Note that VHD is only included when explicitly requested via <c='em'>-Asset Vhd</c>."
				return
			}
		}

		$buildDashed = $fullBuild.Replace(".", "-")

		if ($Download) {
			$downloadDir = Join-Path $Path $fullBuild

			$null = New-Item -Path $downloadDir `
				-ItemType Directory `
				-Force `
				-WarningAction SilentlyContinue
		}

		$colAssets = @(
			foreach ($name in $wanted) {
				if ($name -eq 'Vhd') {
					if ([string]::IsNullOrWhiteSpace($trackAppVersion)) {
						Write-PSFMessage -Level Important -Message "Skipping <c='em'>Vhd</c>: the application version for build <c='em'>$fullBuild</c> is unknown."
						continue
					}

					try {
						$vhdUris = Invoke-RestMethod -Method Get `
							-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/vhd?version=$($trackAppVersion.Replace('.', '-'))" `
							-Headers $headers
					}
					catch {
						Write-PSFMessage -Level Important -Message "Skipping <c='em'>Vhd</c> for <c='em'>$trackAppVersion</c>: $($_.Exception.Message)" -ErrorRecord $_
						continue
					}

					foreach ($vhdUri in @($vhdUris)) {
						$vhdFileName = (Split-Path "$vhdUri" -Leaf).Split("?")[0]

						[PsCustomObject][Ordered]@{
							"Asset"    = "Vhd"
							"Kind"     = "Vhd"
							"FileName" = $vhdFileName
							"Build"    = $fullBuild
							"Uri"      = "$vhdUri"
						}
					}

					continue
				}

				try {
					if ($nugetMap.Contains($name)) {
						$packageId = $nugetMap[$name]
						$assetUri = Invoke-RestMethod -Method Get `
							-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/nugetpackage?packageName=$([uri]::EscapeDataString($packageId))&version=$buildDashed" `
							-Headers $headers
					}
					else {
						$assetUri = Invoke-RestMethod -Method Get `
							-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/$($fileEndpoints[$name])?version=$buildDashed" `
							-Headers $headers
					}
				}
				catch {
					Write-PSFMessage -Level Important -Message "Skipping <c='em'>$name</c> for build <c='em'>$fullBuild</c>: not published for this build." -ErrorRecord $_
					continue
				}

				$assetFileName = (Split-Path "$assetUri" -Leaf).Split("?")[0]

				$assetKind = if ($nugetMap.Contains($name)) { "NuGet" } else { "DeveloperFile" }

				[PsCustomObject][Ordered]@{
					"Asset"    = $name
					"Kind"     = $assetKind
					"FileName" = $assetFileName
					"Build"    = $fullBuild
					"Uri"      = "$assetUri"
				}
			}
		)

		if (-not $Download) {
			$colAssets | Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsAsset" `
				-Property *, `
			@{Name = "Status"; Expression = { "Available" } }
			return
		}

		if (-not [System.IO.File]::Exists($executable)) {
			$messageString = "AzCopy executable not found at <c='em'>$executable</c>. Please install AzCopy using <c='em'>Invoke-BapInstallAzCopy</c> or configure the path using <c='em'>Set-BapAzCopyPath</c>."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because AzCopy executable was not found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if ($PSBoundParameters.ContainsKey('OutputPath') -and -not [string]::IsNullOrWhiteSpace($OutputPath)) {
			$baseRoot = Join-Path $OutputPath $fullBuild
			$pathNugetsRoot = Join-Path $baseRoot "NuGets"
			$pathPackagesLocalDirectory = Join-Path $baseRoot "PackagesLocalDirectory"
		}
		else {
			$pathNugetsRoot = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$fullBuild\NuGets"
			$pathPackagesLocalDirectory = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$fullBuild\PackagesLocalDirectory"
		}

		$retryCount = 0
		$maxRetries = 5

		do {
			$retryCount++

			foreach ($assetObj in $colAssets) {
				$outputPath = Join-Path $downloadDir $assetObj.FileName
				$assetObj | Add-Member -NotePropertyName "Path" -NotePropertyValue $outputPath -Force

				if ([System.IO.File]::Exists($outputPath) -and -not $Force) {
					Write-PSFMessage -Level Verbose -Message "Skipping $($assetObj.FileName), already on disk. Use -Force to re-download."
					$assetObj | Add-Member -NotePropertyName "Status" -NotePropertyValue "Skipped" -Force
					continue
				}

				Write-PSFMessage -Level Important -Message "Downloading <c='em'>$($assetObj.FileName)</c>..."

				try {
					$azCopyOut = & $executable copy "$($assetObj.Uri)" "$outputPath" --overwrite=true 2>&1
					Write-PSFMessage -Level Verbose -Message ($azCopyOut -join [Environment]::NewLine)
				}
				catch {
					Write-PSFMessage -Level Important -Message "Download of <c='em'>$($assetObj.FileName)</c> failed: $($_.Exception.Message)" -ErrorRecord $_
				}

				if ([System.IO.File]::Exists($outputPath)) {
					Unblock-File -Path $outputPath
					$assetObj | Add-Member -NotePropertyName "Status" -NotePropertyValue "Downloaded" -Force
				}
				else {
					$assetObj | Add-Member -NotePropertyName "Status" -NotePropertyValue "Failed" -Force
				}
			}
		} while (
			($colAssets | `
				Where-Object { $_.Status -ne "Downloaded" -and $_.Status -ne "Skipped" }) `
				-and $retryCount -lt $maxRetries
		)

		foreach ($assetObj in $colAssets) {
			$assetObj | Add-Member -NotePropertyName "ExtractedPath" -NotePropertyValue $null -Force

			if ($assetObj.Status -ne "Downloaded" -and -not ([System.IO.File]::Exists($assetObj.Path))) {
				continue
			}

			if ($assetObj.Asset -in @($nugetMap.Keys)) {
				$null = New-Item -Path $pathNugetsRoot `
					-ItemType Directory `
					-Force `
					-WarningAction SilentlyContinue

				$extractDirName = [System.IO.Path]::GetFileNameWithoutExtension($assetObj.Path)
				$extractPath = Join-Path $pathNugetsRoot $extractDirName
				$assetObj.ExtractedPath = $extractPath

				if ([System.IO.Path]::Exists($extractPath) -and -not $Force) {
					Write-PSFMessage -Level Verbose -Message "Extraction of $extractDirName already in place. Use -Force to re-extract."
					continue
				}

				if ([System.IO.Path]::Exists($extractPath)) {
					Remove-Item -Path $extractPath -Recurse -Force
				}

				Write-PSFMessage -Level Important -Message "Extracting <c='em'>$extractDirName</c>..."
				[IO.Compression.ZipFile]::ExtractToDirectory($assetObj.Path, $extractPath, $true)
			}
			elseif ($assetObj.Asset -eq "SystemMetadata") {
				$assetObj.ExtractedPath = $pathPackagesLocalDirectory

				if ([System.IO.Path]::Exists($pathPackagesLocalDirectory) -and -not $Force) {
					Write-PSFMessage -Level Verbose -Message "PackagesLocalDirectory already in place. Use -Force to re-extract."
					continue
				}

				Write-PSFMessage -Level Important -Message "Extracting <c='em'>PackagesLocalDirectory</c> for build <c='em'>$fullBuild</c>..."
				[IO.Compression.ZipFile]::ExtractToDirectory($assetObj.Path, $pathPackagesLocalDirectory, $true)
			}
		}

		[GC]::Collect()
		[GC]::WaitForPendingFinalizers()

		$colAssets | Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsAsset" `
			-Property *
	}

	end {
	}
}
