
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
        Deprecated and ignored; will be removed on 2027-03-31. Version details are always included.

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

        It will retrieve the same output as without the parameter.
        It applies -SkipVersionDetails, which is deprecated and ignored.
        It will be removed on 2027-03-31.

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
	[OutputType('D365Bap.Tools.UdeEnvironment[]')]
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
		if ($PSBoundParameters.ContainsKey('SkipVersionDetails')) {
			$objCaller = @(Get-PSCallStack)[1]
			$objModule = $MyInvocation.MyCommand.Module

			if (($null -eq $objModule) `
					-or (-not [object]::ReferenceEquals($objModule, $objCaller.InvocationInfo.MyCommand.Module))) {
				Write-BapDeprecationNotice -Key 'Get-UnifiedEnvironment.SkipVersionDetails'
			}
		}

		$colEnv = Get-BapEnvironment -EnvironmentId $EnvironmentId `
			-FscmEnabled

		$searchById = Test-Guid -InputObject $EnvironmentId

		$currentProgress = $ProgressPreference
		$ProgressPreference = "SilentlyContinue"
	}

	process {
		$colFilteredEnvs = @(
			$colEnv |
			Where-Object FinOpsMetadataEnvType -eq "Internal"
		)

		if ($searchById) {
			$colFilteredEnvs = @(
				$colFilteredEnvs |
				Where-Object PpacEnvId -like $EnvironmentId
			)
		}
		else {
			$colFilteredEnvs = @(
				$colFilteredEnvs |
				Where-Object PpacEnvName -like $EnvironmentId
			)
		}

		$hashFinOpsProperties = @{}

		if ($colFilteredEnvs.Count -gt 0) {
			$objSecureTokenPowerApi = Get-BapAccessToken -PowerPlatform
			$tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText `
				-SecureString $objSecureTokenPowerApi

			$hashFinOpsProperties = Get-FinOpsEnvironmentProperty `
				-EnvironmentId @($colFilteredEnvs.PpacEnvId) `
				-Token $tokenPowerApiValue
		}

		$colMissedEnvs = [System.Collections.Generic.List[object]]::new()

		$colRes = @(
			foreach ($itemEnv in $colFilteredEnvs) {
				$tmpResponse = $hashFinOpsProperties[$itemEnv.PpacEnvId]

				$provisioningApp = ''
				$provisioningPlatform = ''
				$provisioningType = ''
				$deploymentType = ''

				if (-not ($null -eq $tmpResponse)) {
					$provisioningApp = "$($tmpResponse.applicationVersion)"
					$provisioningPlatform = "$($tmpResponse.platformVersion)"
					$deploymentType = "$($tmpResponse.deploymentType)"
					$provisioningType = switch ($deploymentType) {
						"UnifiedDeveloper" { "OnlineDev" }
						"UnifiedSandbox" { "Sandbox" }
						"Sandbox" { "Sandbox" }
						default {
							if (-not [string]::IsNullOrWhiteSpace($tmpResponse.deploymentType)) {
								Write-PSFMessage -Level Verbose `
									-Message "Unmapped deployment type <c='em'>$($tmpResponse.deploymentType)</c> for <c='em'>$($itemEnv.PpacEnvName)</c>."
							}

							"$($tmpResponse.deploymentType)"
						}
					}
				}
				else {
					$messageString = "Could not obtain the <c='em'>FinOps properties</c> for <c='em'>$($itemEnv.PpacEnvName)</c>. It could be due to insufficient permissions or the environment not being fully provisioned. Please try to access the environment details from PowerPlatform Admin Center (PPAC)."
					Write-PSFMessage -Level Important `
						-Message $messageString

					$messageUrl = "- <c='em'>https://admin.powerplatform.microsoft.com/environments/environment/{0}/hub</c>" `
						-f $itemEnv.PpacEnvId

					Write-PSFHostColor -String $messageUrl
				}

				$tmpVerInfo = $null
				$missed = $false

				if (-not [string]::IsNullOrWhiteSpace($provisioningApp.Trim())) {
					$tmpVerInfo = Resolve-FinOpsVersionFromCache `
						-Build $provisioningApp.Trim() `
						-ErrorAction SilentlyContinue

					if ($null -eq $tmpVerInfo) {
						$missed = $true
					}
				}

				$appVersion = ''
				$appBuild = ''
				$platVersion = ''
				$platBuild = ''

				if (-not ($null -eq $tmpVerInfo)) {
					$appVersion = "$($tmpVerInfo.AppVersion)"
					$appBuild = "$($tmpVerInfo.AppBuild)"
					$platVersion = "$($tmpVerInfo.PlatVersion)"
					$platBuild = "$($tmpVerInfo.PlatBuild)"
				}

				$tmpVersionProperties = @(
					@{Name = "AppVersion"; Expression = { $appVersion } }
					@{Name = "AppBuild"; Expression = { $appBuild } }
					@{Name = "Track"; Expression = { $appBuild } }
					@{Name = "Build"; Expression = { $provisioningApp } }
					@{Name = "PlatVersion"; Expression = { $platVersion } }
					@{Name = "PlatBuild"; Expression = { $platBuild } }
					@{Name = "PlatformVersion"; Expression = { $provisioningPlatform } }
				)

				$tmpProjected = $itemEnv |
				Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" `
					-ExcludeProperty EnvType, Name, Id `
					-Property (@(
						@{Name = "PpacProvApp"; Expression = { $provisioningApp } }
						@{Name = "PpacProvPlatform"; Expression = { $provisioningPlatform } }
						@{Name = "PpacProvType"; Expression = { $provisioningType } }
						@{Name = "DeployType"; Expression = { $deploymentType } }
						@{Name = "FinOpsUri"; Expression = { $_.FinOpsEnvUri } }
						@{Name = "PpeUri"; Expression = { $_.PpacEnvUri } }
						@{Name = "PpacRuntimeState"; Expression = { "$($_.Properties.states.runtime.id)" } }
						@{Name = "RuntimeState"; Expression = { "$($_.Properties.states.runtime.id)" } }
						@{Name = "EnvType"; Expression = {
								switch ($provisioningType) {
									"OnlineDev" { "UDE" }
									"Sandbox" { "USE" }
									Default { "N/A" }
								}
							}
						}
						@{Name = "Name"; Expression = { $_.PpacEnvName } }
						@{Name = "Id"; Expression = { $_.EnvId } }
					) + $tmpVersionProperties + @('*'))

				if ($missed) {
					$colMissedEnvs.Add($tmpProjected)
				}

				$tmpProjected
			}
		)

		if ($UdeOnly) {
			$colRes = $colRes |
			Where-Object EnvType -eq "UDE"
		}
		elseif ($UseOnly) {
			$colRes = $colRes |
			Where-Object EnvType -eq "USE"
		}

		if ($colMissedEnvs.Count -gt 0) {
			$colAuthCandidates = @(@($colRes) + @($colFilteredEnvs))
			$colAuthEnv = @(
				$colAuthCandidates |
				Where-Object {
					(-not ($null -eq $_)) `
						-and (-not [string]::IsNullOrWhiteSpace($_.PpacEnvUri))
				} | Select-Object -First 1
			)

			if (@($colAuthEnv).Count -gt 0) {
				try {
					$authUri = "$($colAuthEnv[0].PpacEnvUri)".TrimEnd("/") + "/"
					$objSecureLive = Get-BapAccessToken -ResourceUrl $authUri
					$liveToken = ConvertFrom-SecureString -AsPlainText `
						-SecureString $objSecureLive

					$hashLiveHeaders = @{
						"Correlationid"           = [guid]::NewGuid().ToString()
						"Dataverseenvironmenturi" = "$($colAuthEnv[0].PpacEnvUri)"
						"Authorization"           = "Bearer $liveToken"
						"Odata-Maxversion"        = "4.0"
						"Odata-Version"           = "4.0"
						"Accept"                  = "application/json"
					}

					$liveCatalog = Invoke-RestMethod -Method Get `
						-Uri "https://developertools.powerplatform.microsoft.com/api/clientmetadata/finopsversions" `
						-Headers $hashLiveHeaders `
						-ErrorAction Stop

					if ((-not ($null -eq $liveCatalog)) `
							-and (@($liveCatalog).Count -gt 0)) {
						Write-FinOpsVersionCache -Versions @($liveCatalog)

						foreach ($itemMissedEnv in @($colMissedEnvs)) {
							$tmpMissedBuild = "$($itemMissedEnv.PpacProvApp)".Trim()
							$tmpMissedInfo = Resolve-FinOpsVersionFromCache `
								-Build $tmpMissedBuild `
								-ErrorAction SilentlyContinue

							if ($null -eq $tmpMissedInfo) { continue }

							$itemMissedEnv.AppVersion = "$($tmpMissedInfo.AppVersion)"
							$itemMissedEnv.AppBuild = "$($tmpMissedInfo.AppBuild)"
							$itemMissedEnv.Track = "$($tmpMissedInfo.AppBuild)"
							$itemMissedEnv.PlatVersion = "$($tmpMissedInfo.PlatVersion)"
							$itemMissedEnv.PlatBuild = "$($tmpMissedInfo.PlatBuild)"
						}
					}
				}
				catch {
					Write-PSFMessage -Level Verbose `
						-Message "FinOps version catalog refresh skipped: $($_.Exception.Message)"
				}
			}
		}

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel `
				-WorksheetName "Get-UnifiedEnvironment" `
				-NoNumberConversion PpacProvApp, PpacProvPlatform, AppVersion, AppBuild, Track, Build, PlatVersion, PlatBuild, PlatformVersion

			return
		}

		$colRes
	}

	end {
		$ProgressPreference = $currentProgress
	}
}
