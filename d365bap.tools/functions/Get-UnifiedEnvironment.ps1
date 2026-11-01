
<#
    .SYNOPSIS
        Get Unified Environments from Power Platform Admin Center.

    .DESCRIPTION
        Retrieves information about Unified Environments in Power Platform Admin Center (PPAC).

        Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).

    .PARAMETER EnvironmentId
        Environment name, GUID, or LCS ID to retrieve. Supports wildcards.

        Default: "*".

    .PARAMETER SkipVersionDetails
        Skips the per-environment version lookup for faster results.

    .PARAMETER UdeOnly
        Instructs the function to only return UDE environments.

    .PARAMETER UseOnly
        Instructs the function to only return USE environments.

    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment

        It will retrieve all available UDE, USE, and UPE environments.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -EnvironmentId "env-123"

        It will retrieve a single UDE, USE, or UPE environment.
        It applies -EnvironmentId to match name, GUID, or LCS ID.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -SkipVersionDetails

        It will retrieve all environments without version details.
        It applies -SkipVersionDetails to skip the version lookup.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -UdeOnly

        It will retrieve only UDE environments.
        It applies -UdeOnly to exclude USE environments.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -UseOnly

        It will retrieve only USE environments.
        It applies -UseOnly to exclude UDE environments.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -AsExcelOutput

        It will export the retrieved environments to an Excel file.
        It applies -AsExcelOutput to write the results to Excel.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UnifiedEnvironment {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	[OutputType('System.Object[]')]
	param (
		[SupportsWildcards()]
		[string] $EnvironmentId = "*",

		[Parameter(ParameterSetName = "SkipVersion")]
		[switch] $SkipVersionDetails,

		[Parameter(ParameterSetName = "UdeOnly")]
		[switch] $UdeOnly,

		[Parameter(ParameterSetName = "UseOnly")]
		[switch] $UseOnly,

		[switch] $AsExcelOutput
	)

	begin {
		$colEnv = Get-BapEnvironment -EnvironmentId $EnvironmentId `
			-FscmEnabled

		$searchById = Test-Guid -InputObject $EnvironmentId

		$currentProgress = $ProgressPreference
		$ProgressPreference = "SilentlyContinue"
	}

	process {
		$filteredEnvs = $colEnv | Where-Object FinOpsMetadataEnvType -eq "Internal"

		# ForEach-Object -Parallel runs in isolated runspaces that do not
		# inherit module functions (Get-BapAccessToken is unavailable there).
		# Mint the Power Platform API token up-front and pass it via $using:.
		$tokenPowerApiValue = ''

		if (-not $SkipVersionDetails -and @($filteredEnvs).Count -gt 0) {
			$secureTokenPowerApi = Get-BapAccessToken -PowerPlatform
			$tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
		}

		$resCol = $filteredEnvs | ForEach-Object -Parallel {
			$envObj = $_
			$localTokenPowerApi = $using:tokenPowerApiValue
			$localHeadersPowerApi = @{
				Authorization = "Bearer $localTokenPowerApi"
			}

			if ($using:searchById) {
				if (-not ($envObj.PpacEnvId -like $using:EnvironmentId)) { continue }
			}
			else {
				if (-not ($envObj.PpacEnvName -like $using:EnvironmentId)) { continue }
			}

			if ($using:SkipVersionDetails) {
				$envObj

				continue
			}

			Import-Module PSFramework -ErrorAction SilentlyContinue

			# Version details come from the Power Platform API FinOps properties endpoint.
			$Response = $null

			try {
				$Response = Invoke-RestMethod `
					-Uri "https://api.powerplatform.com/dynamics/environments/$($envObj.PpacEnvId)/finopsproperties?api-version=2024-10-01" `
					-Method Get `
					-Headers $localHeadersPowerApi
			}
			catch {
				$Response = $null
			}

			$provisioningApp = ''
			$provisioningPlatform = ''
			$provisioningType = ''

			if ($null -ne $Response) {
				$provisioningApp = "$($Response.applicationVersion)"
				$provisioningPlatform = "$($Response.platformVersion)"
				$provisioningType = switch ("$($Response.deploymentType)") {
					"UnifiedDeveloper" { "OnlineDev" }
					"Sandbox" { "Sandbox" }
					default { "$($Response.deploymentType)" }
				}
			}
			else {
				$messageString = "Could not obtain the <c='em'>FinOps properties</c> for <c='em'>$($envObj.PpacEnvName)</c>. It could be due to insufficient permissions or the environment not being fully provisioned. Please try to access the environment details from PowerPlatform Admin Center (PPAC)."
				Write-PSFMessage -Level Important -Message $messageString
				Write-PSFHostColor -String "- <c='em'>https://admin.powerplatform.microsoft.com/environments/environment/$($envObj.PpacEnvId)/hub</c>"
			}

			$envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" `
				-ExcludeProperty EnvType `
				-Property @{Name = "PpacProvApp"; Expression = { $provisioningApp } },
			@{Name = "PpacProvPlatform"; Expression = { $provisioningPlatform } },
			@{Name = "PpacProvType"; Expression = { $provisioningType } },
			@{Name = "EnvType"; Expression = {
					switch ($provisioningType) {
						"OnlineDev" { "UDE" }
						"Sandbox" { "USE" }
						Default { "N/A" }
					}
				}
			},
			*
		}

		if ($UdeOnly) {
			$resCol = $resCol | Where-Object EnvType -eq "UDE"
		}
		elseif ($UseOnly) {
			$resCol = $resCol | Where-Object EnvType -eq "USE"
		}

		if (-not $SkipVersionDetails) {
			$missedEnvs = @()

			$resCol = @(
				foreach ($envObj in @($resCol)) {
					if ($null -eq $envObj) { continue }

					$provApp = "$($envObj.PpacProvApp)".Trim()
					$provPlatform = "$($envObj.PpacProvPlatform)".Trim()
					$missed = $false

					if ([string]::IsNullOrWhiteSpace($provApp)) {
						$verInfo = $null
					}
					else {
						$verInfo = Resolve-FinOpsVersionFromCache -Build $provApp -ErrorAction SilentlyContinue

						if ($null -eq $verInfo) {
							$missed = $true
						}
					}

					$appVersion = if ($null -ne $verInfo) { "$($verInfo.AppVersion)" } else { "" }
					$appBuild = if ($null -ne $verInfo) { "$($verInfo.AppBuild)" } else { "" }
					$platVersion = if ($null -ne $verInfo) { "$($verInfo.PlatVersion)" } else { "" }
					$platBuild = if ($null -ne $verInfo) { "$($verInfo.PlatBuild)" } else { "" }

					$versionProperties = @(
						@{Name = "AppVersion"; Expression = { $appVersion } }
						@{Name = "AppBuild"; Expression = { $appBuild } }
						@{Name = "Track"; Expression = { $appBuild } }
						@{Name = "Build"; Expression = { $provApp } }
						@{Name = "PlatVersion"; Expression = { $platVersion } }
						@{Name = "PlatBuild"; Expression = { $platBuild } }
						@{Name = "PlatformVersion"; Expression = { $provPlatform } }
					)

					$projected = $envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" -Property (@('*') + $versionProperties)

					if ($missed) {
						$missedEnvs += $projected
					}

					$projected
				}
			)

			if (@($missedEnvs).Count -gt 0) {
				$authEnv = @((@($resCol) + @($filteredEnvs)) | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace("$($_.PpacEnvUri)") } | Select-Object -First 1)

				if (@($authEnv).Count -gt 0) {
					try {
						$authUri = "$($authEnv[0].PpacEnvUri)".TrimEnd("/") + "/"
						$secureLive = Get-BapAccessToken -ResourceUrl $authUri
						$liveToken = ConvertFrom-SecureString -AsPlainText -SecureString $secureLive

						$liveHeaders = @{
							"Correlationid"           = [guid]::NewGuid().ToString()
							"Dataverseenvironmenturi" = "$($authEnv[0].PpacEnvUri)"
							"Authorization"           = "Bearer $liveToken"
							"Odata-Maxversion"        = "4.0"
							"Odata-Version"           = "4.0"
							"Accept"                  = "application/json"
						}

						$liveCatalog = Invoke-RestMethod -Method Get `
							-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
							-Headers $liveHeaders `
							-ErrorAction Stop

						if ($null -ne $liveCatalog -and @($liveCatalog).Count -gt 0) {
							Write-FinOpsVersionCache -Versions @($liveCatalog)

							foreach ($missedEnv in @($missedEnvs)) {
								$missedBuild = "$($missedEnv.PpacProvApp)".Trim()
								$missedInfo = Resolve-FinOpsVersionFromCache -Build $missedBuild -ErrorAction SilentlyContinue

								if ($null -eq $missedInfo) { continue }

								$missedEnv.AppVersion = "$($missedInfo.AppVersion)"
								$missedEnv.AppBuild = "$($missedInfo.AppBuild)"
								$missedEnv.Track = "$($missedInfo.AppBuild)"
								$missedEnv.PlatVersion = "$($missedInfo.PlatVersion)"
								$missedEnv.PlatBuild = "$($missedInfo.PlatBuild)"
							}
						}
					}
					catch {
						Write-PSFMessage -Level Verbose -Message "FinOps version catalog refresh skipped: $($_.Exception.Message)"
					}
				}
			}
		}

		if ($AsExcelOutput) {
			$resCol | Export-Excel `
				-WorksheetName "Get-UnifiedEnvironment" `
				-NoNumberConversion PpacProvApp, PpacProvPlatform, AppVersion, AppBuild, Track, Build, PlatVersion, PlatBuild, PlatformVersion
			return
		}

		$resCol
	}

	end {
		$ProgressPreference = $currentProgress
	}
}
