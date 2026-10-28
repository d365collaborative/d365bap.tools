
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
		[Parameter()]
		[string] $EnvironmentId = "*",

		[Parameter(ParameterSetName = "SkipVersion")]
		[switch] $SkipVersionDetails,

		[Parameter(ParameterSetName = "UdeOnly")]
		[switch] $UdeOnly,

		[Parameter(ParameterSetName = "UseOnly")]
		[switch] $UseOnly,

		[Parameter()]
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
		# Mint all tokens up-front and pass plain-text values via $using:.
		$dataverseTokenMap = @{}

		if (-not $SkipVersionDetails -and @($filteredEnvs).Count -gt 0) {
			$distinctUris = @($filteredEnvs |
				Select-Object -ExpandProperty PpacEnvUri -Unique |
				Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

			foreach ($uri in $distinctUris) {
				$secure = Get-BapAccessToken -ResourceUrl $uri
				$dataverseTokenMap[$uri] = ConvertFrom-SecureString -AsPlainText -SecureString $secure
			}
		}

		$resCol = $filteredEnvs | ForEach-Object -Parallel {
			$envObj = $_
			$localTokenMap = $using:dataverseTokenMap

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

			# Version details come from the Web API function msprov_getfinopsapplicationdetails
			$baseUri = $envObj.PpacEnvUri
			$tokenWebApiValue = $localTokenMap[$baseUri]

			$headersApi = @{
				Authorization      = "Bearer $($tokenWebApiValue)"
				Accept             = "application/json"
				"OData-MaxVersion" = "4.0"
				"OData-Version"    = "4.0"
			}

			$Response = $null

			try {
				$Response = Invoke-RestMethod `
					-Uri "$($baseUri.TrimEnd('/'))/api/data/v9.2/msprov_getfinopsapplicationdetails()" `
					-Method Get `
					-Headers $headersApi
			}
			catch {
				$Response = $null
			}

			if ($null -eq $Response) {
				$messageString = "Could not obtain the <c='em'>Ppac Provision</c> details for <c='em'>$($envObj.PpacEnvName)</c>. It could be due to insufficient permissions or the environment not being fully provisioned. Please try to access the environment details from PowerPlatform Admin Center (PPAC)."
				Write-PSFMessage -Level Important -Message $messageString
				Write-PSFHostColor -String "- <c='em'>https://admin.powerplatform.microsoft.com/environments/environment/$($envObj.PpacEnvId)/hub</c>"
			}
			else {
				$envObj | Add-Member -NotePropertyName "ProvisioningAppVersion" -NotePropertyValue $Response.applicationversion
				$envObj | Add-Member -NotePropertyName "ProvisioningPlatVersion" -NotePropertyValue $Response.platformversion
				$envObj | Add-Member -NotePropertyName "ProvisioningState" -NotePropertyValue $Response.finopsenvironmentstate
				$envObj | Add-Member -NotePropertyName "ProvisioningType" -NotePropertyValue $Response.applicationdeploymenttype
			}

			$envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" `
				-ExcludeProperty EnvType `
				-Property "ProvisioningAppVersion as PpacProvApp",
			"ProvisioningPlatVersion as PpacProvPlatform",
			"ProvisioningState as PpacProvState",
			"ProvisioningType as PpacProvType",
			@{Name = "EnvType"; Expression = {
					switch ($_.ProvisioningType) {
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

			foreach ($envObj in @($resCol)) {
				if ($null -eq $envObj) { continue }

				$provApp = "$($envObj.PpacProvApp)".Trim()
				$provPlatform = "$($envObj.PpacProvPlatform)".Trim()

				if ([string]::IsNullOrWhiteSpace($provApp)) {
					$verInfo = $null
				}
				else {
					$verInfo = Resolve-FinOpsVersionFromCache -Build $provApp -ErrorAction SilentlyContinue

					if ($null -eq $verInfo) {
						$missedEnvs += $envObj
					}
				}

				$appVersion = if ($null -ne $verInfo) { "$($verInfo.AppVersion)" } else { "" }
				$appBuild = if ($null -ne $verInfo) { "$($verInfo.AppBuild)" } else { "" }
				$platVersion = if ($null -ne $verInfo) { "$($verInfo.PlatVersion)" } else { "" }
				$platBuild = if ($null -ne $verInfo) { "$($verInfo.PlatBuild)" } else { "" }

				$envObj | Add-Member -NotePropertyName "AppVersion" -NotePropertyValue $appVersion -Force
				$envObj | Add-Member -NotePropertyName "AppBuild" -NotePropertyValue $appBuild -Force
				$envObj | Add-Member -NotePropertyName "Track" -NotePropertyValue $appBuild -Force
				$envObj | Add-Member -NotePropertyName "Build" -NotePropertyValue $provApp -Force
				$envObj | Add-Member -NotePropertyName "PlatVersion" -NotePropertyValue $platVersion -Force
				$envObj | Add-Member -NotePropertyName "PlatBuild" -NotePropertyValue $platBuild -Force
				$envObj | Add-Member -NotePropertyName "PlatformVersion" -NotePropertyValue $provPlatform -Force
			}

			if (@($missedEnvs).Count -gt 0) {
				$authEnv = @((@($resCol) + @($filteredEnvs)) | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace("$($_.PpacEnvUri)") -and $dataverseTokenMap.ContainsKey("$($_.PpacEnvUri)") } | Select-Object -First 1)

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
				-NoNumberConversion PpacProvApp, PpacProvPlatform, ProvisioningAppVersion, ProvisioningPlatVersion, AppVersion, AppBuild, Track, Build, PlatVersion, PlatBuild, PlatformVersion
			return
		}

		$resCol
	}

	end {
		$ProgressPreference = $currentProgress
	}
}
