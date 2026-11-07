<#
    .SYNOPSIS
        Downloads FinOps assets for any build.

    .DESCRIPTION
        Resolves and downloads NuGet packages, developer files and VHD images. Any published version can be selected.

    .PARAMETER Build
		Full build or track. Uses newest when no environment is selected.

    .PARAMETER AppVersion
		Track selector. Omitted: from -Build, else newest.

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
        Custom extraction root. Build and asset folders are appended.

    .PARAMETER Force
        Re-download files and re-extract folders.

    .PARAMETER EnvironmentId
		Authentication environment. Without a build or track, uses its provisioned build.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46"

        Resolves download URLs for that build.
        It selects the version with -Build.
        It keeps downloads under the default -Path.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsBuild -Latest | Get-PpacFinOpsAsset -Kind NuGet -Download

        Downloads all NuGet packages of the newest build.
        It takes the newest build with -Latest.
        It keeps only the -Kind NuGet packages.
        It downloads the files with -Download.
        It keeps downloads under the default -Path.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.49" -Kind DeveloperFile | Where-Object { $_.Asset -eq 'SystemMetadata' } | Get-PpacFinOpsAsset -Download

        Downloads the system metadata of that track.
        It selects the track with -Build.
        It keeps only the -Kind DeveloperFile files.
        It filters to the SystemMetadata asset.
        It downloads the files with -Download.
        It keeps downloads under the default -Path.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46" -Asset Vhd -Download

        Downloads the VHD image parts.
        It selects the version with -Build.
        It keeps only -Asset Vhd.
        It downloads the files with -Download.
        It keeps downloads under the default -Path.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46" -Kind NuGet -Download -OutputPath "C:\tmp\D365"

        Downloads NuGet files, extracting under C:\tmp\D365.
        It selects the version with -Build.
        It keeps only the -Kind NuGet packages.
        It downloads the files with -Download.
        It extracts under -OutputPath C:\tmp\D365.
        It keeps downloads under the default -Path.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -Build "10.0.2790.46" -AsExcelOutput

        Resolves download URLs for that build into an Excel file.
        It selects the version with -Build.
        It writes an Excel file with -AsExcelOutput.
        It keeps downloads under the default -Path.

    .EXAMPLE
        PS C:\> Get-PpacFinOpsAsset -EnvironmentId "es-ude-motz-01"

        Resolves download URLs for the provisioned build of that environment.
        It uses the environment build with -EnvironmentId.
        It keeps downloads under the default -Path.

	.EXAMPLE
		PS C:\> Get-PpacFinOpsAsset -EnvironmentId "es-ude-motz-01" -Build "10.0.2790.46"

		Resolves download URLs for the specified build using that environment for authentication.
		It selects the version with -Build.
		It authenticates with -EnvironmentId.
		It keeps downloads under the default -Path.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacFinOpsAsset {
	[CmdletBinding(DefaultParameterSetName = 'ByBuild')]
	[OutputType('D365Bap.Tools.PpacFinOpsAsset[]')]
	param (
		[Parameter(ParameterSetName = 'ByBuild', ValueFromPipelineByPropertyName = $true, Position = 0)]
		[Parameter(ParameterSetName = 'ByEnvironment', ValueFromPipelineByPropertyName = $true, Position = 0)]
		[string] $AppVersion,

		[Parameter(ParameterSetName = 'ByBuild', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
		[Parameter(ParameterSetName = 'ByEnvironment', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
		[string] $Build,

		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 2)]
		[ValidateScript({
				if ($_ -notin @('*', 'CompilerPackage', 'Platform', 'Application', 'ApplicationSuite', 'Application1', 'Application2', 'SystemMetadata', 'FinOpsVsix22', 'TraceParser', 'CrossReference', 'Vhd')) {
					throw "Cannot validate argument '$($_)' on parameter 'Asset'. Specify one of: '*', 'CompilerPackage', 'Platform', 'Application', 'ApplicationSuite', 'Application1', 'Application2', 'SystemMetadata', 'FinOpsVsix22', 'TraceParser', 'CrossReference', 'Vhd'."
				}

				$true
			})]
		[SupportsWildcards()]
		[string[]] $Asset = '*',

		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 3)]
		[ValidateScript({
				if ($_ -notin @('*', 'NuGet', 'DeveloperFile', 'Vhd')) {
					throw "Cannot validate argument '$($_)' on parameter 'Kind'. Specify one of: '*', 'NuGet', 'DeveloperFile', 'Vhd'."
				}

				$true
			})]
		[SupportsWildcards()]
		[string] $Kind = '*',

		[switch] $Download,

		[Parameter(Position = 4)]
		[string] $Path = "C:\Temp\d365bap.tools\PpacFinOpsAssets",

		[switch] $Force,

		[Parameter(ParameterSetName = 'ByEnvironment', Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 5)]
		[ValidateNotNullOrEmpty()]
		[Alias("PpacEnvId")]
		[string] $EnvironmentId,

		[Parameter(Position = 6)]
		[string] $OutputPath,

		[switch] $AsExcelOutput
	)

	begin {
		Add-Type -AssemblyName System.IO.Compression.FileSystem

		$executable = Get-PSFConfigValue -FullName "d365bap.tools.path.azcopy"

		$hashNugetMap = [ordered]@{
			"CompilerPackage"  = "Microsoft.Dynamics.AX.Platform.CompilerPackage"
			"Platform"         = "Microsoft.Dynamics.AX.Platform.DevALM.BuildXpp"
			"Application"      = "Microsoft.Dynamics.AX.Application.DevALM.BuildXpp"
			"ApplicationSuite" = "Microsoft.Dynamics.AX.ApplicationSuite.DevALM.BuildXpp"
			"Application1"     = "Microsoft.Dynamics.AX.Application1.DevALM.BuildXpp"
			"Application2"     = "Microsoft.Dynamics.AX.Application2.DevALM.BuildXpp"
		}

		$hashFileEndpoints = [ordered]@{
			"SystemMetadata" = "systemmetadata"
			"FinOpsVsix22"   = "finopsvsix22"
			"TraceParser"    = "traceparser"
			"CrossReference" = "crossreference"
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$isByEnvironment = $PSCmdlet.ParameterSetName -eq 'ByEnvironment'

		if ($isByEnvironment) {
			$hashCtx = Get-DevToolsAuthContext -EnvironmentId $EnvironmentId
		}
		else {
			$hashCtx = Get-DevToolsAuthContext
		}

		if ($null -eq $hashCtx) { return }

		$hashHeaders = @{
			"Correlationid"           = [guid]::NewGuid().ToString()
			"Dataverseenvironmenturi" = $hashCtx.Env.PpacEnvUri
			"Authorization"           = "Bearer $($hashCtx.Token)"
			"Odata-Maxversion"        = "4.0"
			"Odata-Version"           = "4.0"
			"Accept"                  = "application/json"
		}

		try {
			$catalog = Invoke-RestMethod -Method Get `
				-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
				-Headers $hashHeaders
		}
		catch {
			$messageString = "Failed retrieving the FinOps version catalog from the developer tools service."
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-ErrorRecord $_

			Stop-PSFFunction -Message "Stopping because the finopsversions request failed." `
				-ErrorRecord $_

			return
		}

		$objFullBuild = $null
		$track = $null
		$trackAppVersion = $null

		$buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
		$appGiven = $PSBoundParameters.ContainsKey('AppVersion') -and -not [string]::IsNullOrWhiteSpace($AppVersion)

		if (($buildGiven) `
				-and ("$Build" -like '@{*}')) {
			$Build = ''
			$buildGiven = $false
		}

		if (($isByEnvironment) `
				-and (-not $buildGiven) `
				-and (-not $appGiven)) {
			$envBuild = $null

			if (((-not ($null -eq $hashCtx.Env))) `
					-and ((-not ($null -eq $hashCtx.Env.PSObject.Properties['PpacProvApp']))) `
					-and (-not [string]::IsNullOrWhiteSpace($hashCtx.Env.PpacProvApp))) {
				$envBuild = "$($hashCtx.Env.PpacProvApp)"
			}
			else {
				$envObj = Get-Environment -EnvironmentId $EnvironmentId `
					-Unified `
					-VersionDetails |
				Select-Object -First 1

				if ((-not ($null -eq $envObj.PSObject.Properties['PpacProvApp']))) {
					$envBuild = "$($envObj.PpacProvApp)"
				}
			}

			if ([string]::IsNullOrWhiteSpace($envBuild)) {
				$messageString = "Could not determine the provisioned application build for environment <c='em'>$EnvironmentId</c>. Use <c='em'>-Build</c> or <c='em'>-AppVersion</c> instead."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the environment version is unknown." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$Build = $envBuild
			$buildGiven = $true
			$appGiven = $false

			Write-PSFMessage -Level Verbose `
				-Message "Using provisioned build <c='em'>$Build</c> from environment <c='em'>$EnvironmentId</c>."
		}

		$appTrack = $null

		if ($appGiven) {
			$appTrack = Get-FinOpsTrackForAppVersion -Catalog $catalog `
				-AppVersion $AppVersion

			if ($null -eq $appTrack) {
				$valid = ($catalog |
					Sort-Object -Property { [version]$_.appVersion } |
					ForEach-Object { $_.appVersion }) -join ", "
				$messageString = "Unknown application track <c='em'>$AppVersion</c>. Valid application versions are: $valid."
				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because the application track was not recognized." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}
		}

		if ([string]::IsNullOrWhiteSpace($Build)) {
			$colCandidates = @(
				$catalog |
				Sort-Object -Property { [version]$_.appVersion }
			)

			if ($appGiven) {
				$colCandidates = @(
					$colCandidates |
					Where-Object { $_.appBuild -eq $appTrack }
				)
			}

			$colEntry = @($colCandidates |
				Select-Object -Last 1)

			if (($null -eq $colEntry) `
					-or ($colEntry.Count -eq 0)) {
				Stop-PSFFunction -Message "Stopping because the version catalog is empty."
				return
			}

			$track = $colEntry[0].appBuild
			$trackAppVersion = $colEntry[0].appVersion

			try {
				$trackBuilds = Invoke-RestMethod -Method Get `
					-Uri ("https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}" `
						-f $track.Replace('.', '-')) `
					-Headers $hashHeaders
			}
			catch {
				$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
				Write-PSFMessage -Level Important `
					-Message $messageString `
					-ErrorRecord $_

				Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." `
					-ErrorRecord $_

				return
			}

			$objFullBuild = $trackBuilds |
			Sort-Object -Property { [version]$_ } `
				-Descending |
			Select-Object -First 1

			if ([string]::IsNullOrWhiteSpace($objFullBuild)) {
				Stop-PSFFunction -Message "Stopping because no builds were found for track $track."
				return
			}

			$objFullBuild = "$objFullBuild"
		}
		else {
			$normalized = "$Build".Replace("-", ".").Trim()
			$colParts = @($normalized -split "\.")

			if ($colParts.Count -eq 4) {
				$objFullBuild = $normalized
				$track = "$($colParts[0]).$($colParts[1]).$($colParts[2])"
				$colByBuild = @(
					$catalog |
					Where-Object { $_.appBuild -eq $track } |
					Select-Object -First 1
				)

				if ($colByBuild.Count -gt 0) {
					$trackAppVersion = $colByBuild[0].appVersion
				}

				if (($appGiven) `
						-and ($track -ne $appTrack)) {
					$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}
			}
			else {
				$colByAppVersion = @(
					$catalog |
					Where-Object { $_.appVersion -eq $normalized } |
					Select-Object -First 1
				)

				if ($colByAppVersion.Count -gt 0) {
					$track = $colByAppVersion[0].appBuild
					$trackAppVersion = $colByAppVersion[0].appVersion
				}
				else {
					$colByBuild = @(
						$catalog |
						Where-Object { $_.appBuild -eq $normalized } |
						Select-Object -First 1
					)

					if ($colByBuild.Count -gt 0) {
						$track = $colByBuild[0].appBuild
						$trackAppVersion = $colByBuild[0].appVersion
					}
				}

				if ([string]::IsNullOrWhiteSpace($track)) {
					$valid = ($catalog |
						Sort-Object -Property { [version]$_.appVersion } |
						ForEach-Object { $_.appVersion }) -join ", "
					$messageString = "Unknown build or track <c='em'>$Build</c>. Valid application versions are: $valid."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the build was not recognized." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}

				if (($appGiven) `
						-and ($track -ne $appTrack)) {
					$messageString = "Build <c='em'>$Build</c> is not on the <c='em'>$AppVersion</c> track. Specify a matching build or omit <c='em'>-AppVersion</c>."
					Write-PSFMessage -Level Important `
						-Message $messageString

					Stop-PSFFunction -Message "Stopping because the build does not match the application track." `
						-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

					return
				}

				try {
					$trackBuilds = Invoke-RestMethod -Method Get `
						-Uri ("https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsbuilds?version={0}" `
							-f $track.Replace('.', '-')) `
						-Headers $hashHeaders
				}
				catch {
					$messageString = "Failed retrieving FinOps builds for track <c='em'>$track</c> from the developer tools service."
					Write-PSFMessage -Level Important `
						-Message $messageString `
						-ErrorRecord $_

					Stop-PSFFunction -Message "Stopping because the finopsbuilds request failed." `
						-ErrorRecord $_

					return
				}

				$objFullBuild = $trackBuilds |
				Sort-Object -Property { [version]$_ } `
					-Descending |
				Select-Object -First 1

				if ([string]::IsNullOrWhiteSpace($objFullBuild)) {
					Stop-PSFFunction -Message "Stopping because no builds were found for track $track."
					return
				}

				$objFullBuild = "$objFullBuild"
			}
		}

		$assetExplicit = $PSBoundParameters.ContainsKey('Asset')
		$colWanted = @(
			if (-not $assetExplicit) {
				@($hashNugetMap.Keys) + @($hashFileEndpoints.Keys)
			}
			else {
				foreach ($itemName in @($Asset)) {
					if ($itemName -eq '*') {
						@($hashNugetMap.Keys) + @($hashFileEndpoints.Keys) + @('Vhd')
					}
					else {
						$itemName
					}
				}
			}
		)

		if ($assetExplicit) {
			$colWanted = @($colWanted |
				Sort-Object -Unique)
		}

		if ((-not $assetExplicit) `
				-and ($PSBoundParameters.ContainsKey('Kind')) `
				-and (('Vhd' -like $Kind)) `
				-and (('NuGet' -notlike $Kind)) `
				-and ('Vhd' -notin $colWanted)) {
			$colWanted += 'Vhd'
		}

		if ($PSBoundParameters.ContainsKey('Kind')) {
			$kindOf = {
				param ([string] $Name)

				if ($Name -eq 'Vhd') { 'Vhd'; return }
				if ($hashNugetMap.Contains($Name)) { 'NuGet'; return }

				'DeveloperFile'
			}

			$colWanted = @(
				$colWanted |
				Where-Object { (& $kindOf $_) -like $Kind }
			)

			if ($colWanted.Count -eq 0) {
				Write-PSFMessage -Level Important `
					-Message "No assets match <c='em'>$($Asset -join ', ')</c> filtered by kind <c='em'>$Kind</c>. Note that VHD is only included when explicitly requested via <c='em'>-Asset Vhd</c>."

				return
			}
		}

		$buildDashed = $objFullBuild.Replace(".", "-")

		if ($Download) {
			$downloadDir = Join-Path $Path $objFullBuild

			New-Item -Path $downloadDir `
				-ItemType Directory `
				-Force `
				-WarningAction SilentlyContinue > $null
		}

		$colAssets = @(
			foreach ($itemName in $colWanted) {
				if ($itemName -eq 'Vhd') {
					if ([string]::IsNullOrWhiteSpace($trackAppVersion)) {
						Write-PSFMessage -Level Important `
							-Message "Skipping <c='em'>Vhd</c>: the application version for build <c='em'>$objFullBuild</c> is unknown."

						continue
					}

					try {
						$vhdUris = Invoke-RestMethod -Method Get `
							-Uri ("https://developertools.powerplatform.microsoft.com/api/clientmetadata/vhd?version={0}" `
								-f $trackAppVersion.Replace('.', '-')) `
							-Headers $hashHeaders
					}
					catch {
						Write-PSFMessage -Level Important `
							-Message "Skipping <c='em'>Vhd</c> for <c='em'>$trackAppVersion</c>: $($_.Exception.Message)" `
							-ErrorRecord $_

						continue
					}

					foreach ($itemVhdUri in @($vhdUris)) {
						$vhdFileName = (Split-Path "$itemVhdUri" -Leaf).Split("?")[0]

						[PsCustomObject][Ordered]@{
							"Asset"    = "Vhd"
							"Kind"     = "Vhd"
							"FileName" = $vhdFileName
							"Uri"      = "$itemVhdUri"
							"Build"    = $objFullBuild
						}
					}

					continue
				}

				try {
					if ($hashNugetMap.Contains($itemName)) {
						$packageId = $hashNugetMap[$itemName]
						$assetUri = Invoke-RestMethod -Method Get `
							-Uri ("https://developertools.powerplatform.microsoft.com/api/clientmetadata/nugetpackage?packageName={0}&version={1}" `
								-f [uri]::EscapeDataString($packageId),
							$buildDashed) `
							-Headers $hashHeaders
					}
					else {
						$assetUri = Invoke-RestMethod -Method Get `
							-Uri ("https://developertools.powerplatform.microsoft.com/api/clientmetadata/{0}?version={1}" `
								-f $hashFileEndpoints[$itemName],
							$buildDashed) `
							-Headers $hashHeaders
					}
				}
				catch {
					Write-PSFMessage -Level Important `
						-Message "Skipping <c='em'>$itemName</c> for build <c='em'>$objFullBuild</c>: not published for this build." `
						-ErrorRecord $_

					continue
				}

				$assetFileName = (Split-Path "$assetUri" -Leaf).Split("?")[0]

				$assetKind = $hashNugetMap.Contains($itemName) ? "NuGet" : "DeveloperFile"

				[PsCustomObject][Ordered]@{
					"Asset"    = $itemName
					"Kind"     = $assetKind
					"FileName" = $assetFileName
					"Uri"      = "$assetUri"
					"Build"    = $objFullBuild
				}
			}
		)

		Write-FinOpsVersionCache -Versions $catalog
		$hashVersionInfo = Resolve-FinOpsVersionFromCache -Build $objFullBuild
		$mapAppVersion = (-not ($null -eq $hashVersionInfo)) ? $hashVersionInfo.AppVersion : ''
		$mapAppBuild = (-not ($null -eq $hashVersionInfo)) ? $hashVersionInfo.AppBuild : ''
		$mapPlatVersion = (-not ($null -eq $hashVersionInfo)) ? $hashVersionInfo.PlatVersion : ''
		$mapPlatBuild = (-not ($null -eq $hashVersionInfo)) ? $hashVersionInfo.PlatBuild : ''

		try {
			$platformVersion = Invoke-RestMethod -Method Get `
				-Uri ("https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsplatbuild?version={0}" `
					-f $buildDashed) `
				-Headers $hashHeaders

			$mapPlatBuild = "$platformVersion"
			Write-FinOpsVersionCache -Platforms @{ "$objFullBuild" = "$platformVersion" }
		}
		catch {
			Write-PSFMessage -Level Warning `
				-Message "Failed retrieving the platform version for build <c='em'>$objFullBuild</c>. Using cached version metadata." `
				-ErrorRecord $_
		}

		$colAssets = @(
			$colAssets |
			Select-Object -Property *,
			@{Name = "AppVersion"; Expression = { $mapAppVersion } },
			@{Name = "AppBuild"; Expression = { $mapAppBuild } },
			@{Name = "Track"; Expression = { $mapAppBuild } },
			@{Name = "PlatVersion"; Expression = { $mapPlatVersion } },
			@{Name = "PlatBuild"; Expression = { $mapPlatBuild } }
		)

		if ($Download) {
			$colAssets = @(
				$colAssets |
				Select-Object -Property *,
				@{Name = "Path"; Expression = { Join-Path $downloadDir $_.FileName } },
				@{Name = "Status"; Expression = { "" } },
				@{Name = "ExtractedPath"; Expression = { $null } }
			)
		}

		$colAssets = @($colAssets |
			Sort-Object -Property Kind, Asset, FileName)

		if (-not $Download) {
			$output = $colAssets |
			Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsAsset" `
				-Property *, `
			@{Name = "Status"; Expression = { "Available" } }

			if ($AsExcelOutput) {
				$output |
				Export-Excel -WorksheetName "Get-PpacFinOpsAsset" `
					-NoNumberConversion AppVersion, AppBuild, Track, Build, PlatVersion, PlatBuild

				return
			}

			$output
			return
		}

		if (-not [System.IO.File]::Exists($executable)) {
			$messageString = "AzCopy executable not found at <c='em'>$executable</c>. Please install AzCopy using <c='em'>Invoke-BapInstallAzCopy</c> or configure the path using <c='em'>Set-BapAzCopyPath</c>."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because AzCopy executable was not found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		if (($PSBoundParameters.ContainsKey('OutputPath')) `
				-and (-not [string]::IsNullOrWhiteSpace($OutputPath))) {
			$baseRoot = Join-Path $OutputPath $objFullBuild
			$pathNugetsRoot = Join-Path $baseRoot "NuGets"
			$pathPackagesLocalDirectory = Join-Path $baseRoot "PackagesLocalDirectory"
		}
		else {
			$pathNugetsRoot = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$objFullBuild\NuGets"
			$pathPackagesLocalDirectory = "$env:LOCALAPPDATA\Microsoft\Dynamics365\$objFullBuild\PackagesLocalDirectory"
		}

		$retryCount = 0
		$maxRetries = 5

		do {
			$retryCount++

			foreach ($itemAsset in $colAssets) {
				$outputPath = $itemAsset.Path

				if (([System.IO.File]::Exists($outputPath)) `
						-and (-not $Force)) {
					Write-PSFMessage -Level Verbose `
						-Message "Skipping $($itemAsset.FileName), already on disk. Use -Force to re-download."

					$itemAsset.Status = "Skipped"
					continue
				}

				Write-PSFMessage -Level Important `
					-Message "Downloading <c='em'>$($itemAsset.FileName)</c>..."

				try {
					$azCopyOut = & $executable copy "$($itemAsset.Uri)" "$outputPath" --overwrite=true 2>&1
					Write-PSFMessage -Level Verbose `
						-Message ($azCopyOut -join [Environment]::NewLine)
				}
				catch {
					Write-PSFMessage -Level Important `
						-Message "Download of <c='em'>$($itemAsset.FileName)</c> failed: $($_.Exception.Message)" `
						-ErrorRecord $_
				}

				if ([System.IO.File]::Exists($outputPath)) {
					Unblock-File -Path $outputPath
					$itemAsset.Status = "Downloaded"
				}
				else {
					$itemAsset.Status = "Failed"
				}
			}
		} while (
			($colAssets |
			Where-Object { ($_.Status -ne "Downloaded") `
					-and ($_.Status -ne "Skipped") }) `
				-and $retryCount -lt $maxRetries
		)

		foreach ($itemAsset in $colAssets) {
			if (($itemAsset.Status -ne "Downloaded") `
					-and (-not ([System.IO.File]::Exists($itemAsset.Path)))) {
				continue
			}

			if ($itemAsset.Asset -in @($hashNugetMap.Keys)) {
				New-Item -Path $pathNugetsRoot `
					-ItemType Directory `
					-Force `
					-WarningAction SilentlyContinue > $null

				$extractDirName = [System.IO.Path]::GetFileNameWithoutExtension($itemAsset.Path)
				$extractPath = Join-Path $pathNugetsRoot $extractDirName
				$itemAsset.ExtractedPath = $extractPath

				if (([System.IO.Path]::Exists($extractPath)) `
						-and (-not $Force)) {
					Write-PSFMessage -Level Verbose `
						-Message "Extraction of $extractDirName already in place. Use -Force to re-extract."

					continue
				}

				if ([System.IO.Path]::Exists($extractPath)) {
					Remove-Item -Path $extractPath `
						-Recurse `
						-Force
				}

				Write-PSFMessage -Level Important `
					-Message "Extracting <c='em'>$extractDirName</c>..."

				[IO.Compression.ZipFile]::ExtractToDirectory($itemAsset.Path, $extractPath, $true)
			}
			elseif ($itemAsset.Asset -eq "SystemMetadata") {
				$itemAsset.ExtractedPath = $pathPackagesLocalDirectory

				if (([System.IO.Path]::Exists($pathPackagesLocalDirectory)) `
						-and (-not $Force)) {
					Write-PSFMessage -Level Verbose `
						-Message "PackagesLocalDirectory already in place. Use -Force to re-extract."

					continue
				}

				Write-PSFMessage -Level Important `
					-Message "Extracting <c='em'>PackagesLocalDirectory</c> for build <c='em'>$objFullBuild</c>..."

				[IO.Compression.ZipFile]::ExtractToDirectory($itemAsset.Path, $pathPackagesLocalDirectory, $true)
			}
		}

		[GC]::Collect()
		[GC]::WaitForPendingFinalizers()

		$output = $colAssets |
		Select-PSFObject -TypeName "D365Bap.Tools.PpacFinOpsAsset" `
			-Property *

		if ($AsExcelOutput) {
			$output |
			Export-Excel -WorksheetName "Get-PpacFinOpsAsset" `
				-NoNumberConversion AppVersion, AppBuild, Track, Build, PlatVersion, PlatBuild

			return
		}

		$output
	}

	end {
	}
}
