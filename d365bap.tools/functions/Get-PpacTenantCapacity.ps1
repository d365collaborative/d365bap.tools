
<#
	.SYNOPSIS
		Get tenant capacity totals.

	.DESCRIPTION
		Retrieves Power Platform tenant capacity, including base, incremental, and add-on totals with consumption and backing licenses.

	.PARAMETER CapacityType
		Type filter. Wildcards, Ppac, Dataverse, M365, Trial, SubscriptionTrial accepted.

		Default: *

	.PARAMETER ExcludeTrial
		Skips trial and subscription trial types.

	.PARAMETER FinOpsOnly
		Keeps FinOps database and file types only.

	.PARAMETER IncludeEntitlements
		Emits one row per backing entitlement.

	.PARAMETER IncludeLicenses
		Emits one row per backing license.

	.PARAMETER IncludeConsumption
		Adds consumed actual, rated, and percent values.

	.PARAMETER AsAos
		Emits a single AOS tier calculation row. Capacity filters are ignored.

	.PARAMETER Full
		Emits the full capacity envelope object.

	.PARAMETER AsExcelOutput
		Instructs the cmdlet to output the results as an Excel file.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity

		Lists every tenant capacity type.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -CapacityType "Database"

		Shows the Database capacity totals.
		It uses -CapacityType to select the Database type.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -CapacityType Ppac

		Shows the Dataverse capacity totals.
		It uses -CapacityType to select the Ppac alias.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -ExcludeTrial -IncludeConsumption

		Shows consumption without trial types.
		It uses -ExcludeTrial to skip trial capacity types.
		It uses -IncludeConsumption to add consumption details.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -FinOpsOnly

		Shows FinOps capacity types only.
		It uses -FinOpsOnly to select FinOps types.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -IncludeEntitlements

		Lists one row per entitlement.
		It uses -IncludeEntitlements to expand entitlement rows.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -IncludeLicenses

		Lists one row per backing license.
		It uses -IncludeLicenses to expand license rows.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -AsAos

		Shows the AOS tier calculation.
		It uses -AsAos to emit a single AOS row.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -Full

		Shows the full capacity envelope.
		It uses -Full to emit the envelope object.

	.EXAMPLE
		PS C:\> Get-PpacTenantCapacity -AsExcelOutput

		Exports tenant capacities to an Excel workbook.
		It uses -AsExcelOutput to write an Excel file.

	.NOTES
		Author: d365bap.tools contributors
#>
function Get-PpacTenantCapacity {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacTenantCapacity[]', 'D365Bap.Tools.PpacTenantCapacityEntitlement[]', 'D365Bap.Tools.PpacTenantCapacityLicense[]', 'D365Bap.Tools.PpacTenantCapacityAos[]', 'D365Bap.Tools.PpacTenantCapacityFull[]', [object[]])]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string[]] $CapacityType = '*',

		[switch] $ExcludeTrial,

		[switch] $FinOpsOnly,

		[switch] $IncludeEntitlements,

		[switch] $IncludeLicenses,

		[switch] $IncludeConsumption,

		[switch] $AsAos,

		[switch] $Full,

		[switch] $AsExcelOutput
	)

	begin {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$apiVersion = $script:BapApiVersions.PowerPlatform

		$hashHeaders = @{
			Authorization = "Bearer $tokenValue"
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$requestUri = 'https://api.powerplatform.com/licensing/tenantCapacity?api-version={0}' `
			-f $apiVersion

		try {
			$objPayload = Invoke-RestMethod `
				-Method Get `
				-Uri $requestUri `
				-Headers $hashHeaders 4> $null
		}
		catch {
			$messageString = "Failed retrieving tenant capacity. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message 'Stopping because the tenant capacity request failed.' `
				-Exception $_.Exception

			return
		}

		if ($null -eq $objPayload) { return }

		$tenantId = $objPayload.tenantId

		$colPayloadCapacities = @(
			$objPayload.tenantCapacities |
			Where-Object { $_ }
		)

		if ($ExcludeTrial) {
			$colPayloadCapacities = @(
				$colPayloadCapacities |
				Where-Object {
					($_.capacityType -notlike 'Trial*') `
						-and ($_.capacityType -notlike 'SubscriptionTrial*')
				}
			)
		}

		if ($FinOpsOnly) {
			$colPayloadCapacities = @(
				$colPayloadCapacities |
				Where-Object {
					($_.capacityType -eq 'FinOpsDatabase') `
						-or ($_.capacityType -eq 'FinOpsFile')
				}
			)
		}

		$colKnownTypes = @(
			$colPayloadCapacities |
			ForEach-Object { $_.capacityType } |
			Where-Object { $_ } |
			Sort-Object -Unique
		)

		$hashCapacityAliases = @{
			'Ppac'              = @('Database', 'File', 'Log', 'CapacityPass', 'ApiCallCount')
			'Dataverse'         = @('Database', 'File', 'Log', 'CapacityPass', 'ApiCallCount')
			'M365'              = @('M365*')
			'Trial'             = @('Trial*')
			'SubscriptionTrial' = @('SubscriptionTrial*')
		}

		$colExpandedPatterns = @(
			foreach ($itemPattern in $CapacityType) {
				$tmpAliasKeys = @(
					$hashCapacityAliases.Keys |
					Where-Object { $_ -ieq $itemPattern }
				)

				$tmpAliasKey = $tmpAliasKeys |
				Select-Object -First 1

				if ($tmpAliasKey) {
					foreach ($itemExpanded in $hashCapacityAliases[$tmpAliasKey]) {
						$itemExpanded
					}
				}
				else {
					$itemPattern
				}
			}
		)

		$colTargetTypes = @(
			foreach ($itemPattern in $colExpandedPatterns) {
				if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($itemPattern)) {
					$tmpMatchedTypes = @(
						$colKnownTypes |
						Where-Object { $_ -like $itemPattern }
					)

					if ($tmpMatchedTypes.Count -eq 0) {
						$messageString = "No tenant capacity matches pattern '<c='em'>$itemPattern</c>'. Skipping."
						Write-PSFMessage -Level Warning `
							-Message $messageString
					}

					foreach ($itemMatchedType in $tmpMatchedTypes) {
						$itemMatchedType
					}
				}
				else {
					if ($itemPattern -in $colKnownTypes) {
						$itemPattern
					}
					else {
						$messageString = "No tenant capacity found for '<c='em'>$itemPattern</c>'. Skipping."
						Write-PSFMessage -Level Warning `
							-Message $messageString
					}
				}
			}
		)

		$colTargetTypes = @(
			$colTargetTypes |
			Sort-Object -Unique
		)

		$colCapacities = @(
			$colPayloadCapacities |
			Where-Object { $_.capacityType -in $colTargetTypes }
		)

		$colSummaryRows = @(
			foreach ($itemCapacity in $colCapacities) {
				$tmpEntitlements = @(
					$itemCapacity.capacityEntitlements |
					Where-Object { $_ }
				)

				$tmpLicenseCount = 0

				foreach ($itemCountEntitlement in $tmpEntitlements) {
					$tmpCountLicenses = @(
						$itemCountEntitlement.licenses |
						Where-Object { $_ }
					).Count

					$tmpLicenseCount += $tmpCountLicenses
				}

				$tmpBaseSum = @(
					$tmpEntitlements |
					Where-Object { $_.capacitySubType -like '*Base' }
				) |
				Measure-Object `
					-Property totalCapacity `
					-Sum

				$tmpBaseCapacity = [double]$tmpBaseSum.Sum

				$tmpIncrementalSum = @(
					$tmpEntitlements |
					Where-Object { $_.capacitySubType -like '*Incremental' }
				) |
				Measure-Object `
					-Property totalCapacity `
					-Sum

				$tmpIncrementalCapacity = [double]$tmpIncrementalSum.Sum

				$tmpAddOnSum = @(
					$tmpEntitlements |
					Where-Object { $_.capacitySubType -like '*AddOn' }
				) |
				Measure-Object `
					-Property totalCapacity `
					-Sum

				$tmpAddOnCapacity = [double]$tmpAddOnSum.Sum

				$tmpTotalCapacity = $itemCapacity.totalCapacity
				$tmpConsumedActual = $itemCapacity.consumption.actual
				$tmpConsumedRated = $itemCapacity.consumption.rated

				$tmpActualUpdatedOn = $itemCapacity.consumption.actualUpdatedOn

				if (($tmpActualUpdatedOn -is [datetime]) `
						-and ($tmpActualUpdatedOn.Year -eq 1)) {
					$tmpActualUpdatedOn = $null
				}

				$tmpRatedUpdatedOn = $itemCapacity.consumption.ratedUpdatedOn

				if (($tmpRatedUpdatedOn -is [datetime]) `
						-and ($tmpRatedUpdatedOn.Year -eq 1)) {
					$tmpRatedUpdatedOn = $null
				}

				$tmpConsumedPct = $null

				if ((-Not ($null -eq $tmpConsumedRated)) `
						-and ($tmpTotalCapacity -gt 0)) {
					$tmpConsumedPct = $tmpConsumedRated / $tmpTotalCapacity * 100
				}

				if ($IncludeConsumption) {
					$itemCapacity |
					Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacity' `
						-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
					'capacityType as CapacityType',
					'capacityUnits as Units',
					'totalCapacity as TotalCapacity',
					'maxCapacity as MaxCapacity',
					'status as Status',
					@{ Name = 'BaseCapacity'; Expression = { $tmpBaseCapacity } },
					@{ Name = 'IncrementalCapacity'; Expression = { $tmpIncrementalCapacity } },
					@{ Name = 'AddOnCapacity'; Expression = { $tmpAddOnCapacity } },
					@{ Name = 'EntitlementCount'; Expression = { $tmpEntitlements.Count } },
					@{ Name = 'LicenseCount'; Expression = { $tmpLicenseCount } },
					@{ Name = 'ConsumedActual'; Expression = { $tmpConsumedActual } },
					@{ Name = 'ConsumedRated'; Expression = { $tmpConsumedRated } },
					@{ Name = 'ConsumedPct'; Expression = { $tmpConsumedPct } },
					@{ Name = 'ConsumedActualUpdatedOn'; Expression = { $tmpActualUpdatedOn } },
					@{ Name = 'ConsumedRatedUpdatedOn'; Expression = { $tmpRatedUpdatedOn } },
					@{ Name = 'Raw'; Expression = { $itemCapacity } }

					continue
				}

				$itemCapacity |
				Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacity' `
					-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
				'capacityType as CapacityType',
				'capacityUnits as Units',
				'totalCapacity as TotalCapacity',
				'maxCapacity as MaxCapacity',
				'status as Status',
				@{ Name = 'BaseCapacity'; Expression = { $tmpBaseCapacity } },
				@{ Name = 'IncrementalCapacity'; Expression = { $tmpIncrementalCapacity } },
				@{ Name = 'AddOnCapacity'; Expression = { $tmpAddOnCapacity } },
				@{ Name = 'EntitlementCount'; Expression = { $tmpEntitlements.Count } },
				@{ Name = 'LicenseCount'; Expression = { $tmpLicenseCount } },
				@{ Name = 'Raw'; Expression = { $itemCapacity } }
			}
		)

		if ($Full) {
			$objFull = $objPayload |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacityFull' `
				-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
			'licenseModelType as LicenseModelType',
			@{ Name = 'SummaryStatus'; Expression = { $objPayload.capacitySummary.status } },
			@{ Name = 'SummaryMessage'; Expression = { $objPayload.capacitySummary.statusMessage } },
			@{ Name = 'FinOpsStatus'; Expression = { $objPayload.capacitySummary.finOpsStatus } },
			@{ Name = 'FinOpsMessage'; Expression = { $objPayload.capacitySummary.finOpsStatusMessage } },
			'legacyModelCapacity as LegacyModelCapacity',
			'temporaryLicenseInfo as TemporaryLicenseInfo',
			@{ Name = 'TenantCapacities'; Expression = { $colSummaryRows } },
			@{ Name = 'Raw'; Expression = { $objPayload } }

			$colRes = @($objFull)
		}
		elseif ($AsAos) {
			$objApiCapacity = $colPayloadCapacities |
			Where-Object { $_.capacityType -eq 'ApiCallCount' } |
			Select-Object -First 1

			if ($null -eq $objApiCapacity) {
				$messageString = "No ApiCallCount capacity found for '<c='em'>$tenantId</c>'. Skipping."
				Write-PSFMessage -Level Warning `
					-Message $messageString

				return
			}

			$apiTotal = $objApiCapacity.totalCapacity

			if ($null -eq $apiTotal) {
				$apiTotal = 0
			}

			$perAos = 650000
			$minAos = 2
			$maxAos = 80
			$currentAos = [int][Math]::Floor($apiTotal / $perAos)

			if ($currentAos -lt $minAos) {
				$currentAos = $minAos
			}

			if ($currentAos -gt $maxAos) {
				$currentAos = $maxAos
			}

			$intoCurrentTier = $apiTotal - $currentAos * $perAos

			if ($intoCurrentTier -lt 0) {
				$intoCurrentTier = 0
			}

			$toNextAos = ($currentAos + 1) * $perAos - $apiTotal
			$headroomToMax = $maxAos * $perAos - $apiTotal
			$aosStatus = $objApiCapacity.status

			if ($headroomToMax -le 0) {
				$aosStatus = 'Exceeded'
			}

			if ($null -eq $aosStatus) {
				$aosStatus = 'Available'
			}

			$objAos = $objApiCapacity |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacityAos' `
				-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
			@{ Name = 'ApiCallTotal'; Expression = { $apiTotal } },
			@{ Name = 'PerAos'; Expression = { $perAos } },
			@{ Name = 'MinAos'; Expression = { $minAos } },
			@{ Name = 'MaxAos'; Expression = { $maxAos } },
			@{ Name = 'CurrentAos'; Expression = { $currentAos } },
			@{ Name = 'IntoCurrentTier'; Expression = { $intoCurrentTier } },
			@{ Name = 'ToNextAos'; Expression = { $toNextAos } },
			@{ Name = 'HeadroomToMax'; Expression = { $headroomToMax } },
			@{ Name = 'Status'; Expression = { $aosStatus } },
			@{ Name = 'Raw'; Expression = { $objApiCapacity } }

			$colRes = @($objAos)
		}
		elseif ($IncludeLicenses) {
			$colRes = @(
				foreach ($itemLicenseCapacity in $colCapacities) {
					$tmpLicenseEntitlements = @(
						$itemLicenseCapacity.capacityEntitlements |
						Where-Object { $_ }
					)

					foreach ($itemEntitlement in $tmpLicenseEntitlements) {
						$tmpEntLicenses = @(
							$itemEntitlement.licenses |
							Where-Object { $_ }
						)

						foreach ($itemLicense in $tmpEntLicenses) {
							$tmpNextLifecycleDate = $itemLicense.nextLifecycleDate

							if (($tmpNextLifecycleDate -is [datetime]) `
									-and ($tmpNextLifecycleDate.Year -eq 1)) {
								$tmpNextLifecycleDate = $null
							}

							$tmpTemporaryExpiry = $itemLicense.temporaryLicenseExpiryDate

							if (($tmpTemporaryExpiry -is [datetime]) `
									-and ($tmpTemporaryExpiry.Year -eq 1)) {
								$tmpTemporaryExpiry = $null
							}

							$itemLicense |
							Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacityLicense' `
								-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
							@{ Name = 'CapacityType'; Expression = { $itemLicenseCapacity.capacityType } },
							@{ Name = 'CapacitySubType'; Expression = { $itemEntitlement.capacitySubType } },
							'entitlementCode as EntitlementCode',
							'displayName as DisplayName',
							'servicePlanId as ServicePlanId',
							'skuId as SkuId',
							@{ Name = 'PaidEnabled'; Expression = { $itemLicense.paid.enabled } },
							@{ Name = 'PaidWarning'; Expression = { $itemLicense.paid.warning } },
							@{ Name = 'PaidSuspended'; Expression = { $itemLicense.paid.suspended } },
							@{ Name = 'TrialEnabled'; Expression = { $itemLicense.trial.enabled } },
							@{ Name = 'TrialWarning'; Expression = { $itemLicense.trial.warning } },
							@{ Name = 'TrialSuspended'; Expression = { $itemLicense.trial.suspended } },
							'totalCapacity as LicenseTotalCapacity',
							@{ Name = 'NextLifecycleDate'; Expression = { $tmpNextLifecycleDate } },
							'isTemporaryLicense as IsTemporaryLicense',
							@{ Name = 'TemporaryLicenseExpiryDate'; Expression = { $tmpTemporaryExpiry } },
							'capabilityStatus as CapabilityStatus',
							@{ Name = 'Raw'; Expression = { $itemLicense } }
						}
					}
				}
			)
		}
		elseif ($IncludeEntitlements) {
			$colRes = @(
				foreach ($itemEntitlementCapacity in $colCapacities) {
					$tmpCapacityEntitlements = @(
						$itemEntitlementCapacity.capacityEntitlements |
						Where-Object { $_ }
					)

					foreach ($itemCapacityEntitlement in $tmpCapacityEntitlements) {
						$tmpEntLicenseCount = @(
							$itemCapacityEntitlement.licenses |
							Where-Object { $_ }
						).Count

						$tmpMaxNextLifecycle = $itemCapacityEntitlement.maxNextLifecycleDate

						if (($tmpMaxNextLifecycle -is [datetime]) `
								-and ($tmpMaxNextLifecycle.Year -eq 1)) {
							$tmpMaxNextLifecycle = $null
						}

						$tmpEntConsumedActual = $itemEntitlementCapacity.consumption.actual
						$tmpEntConsumedRated = $itemEntitlementCapacity.consumption.rated

						$tmpEntActualUpdatedOn = $itemEntitlementCapacity.consumption.actualUpdatedOn

						if (($tmpEntActualUpdatedOn -is [datetime]) `
								-and ($tmpEntActualUpdatedOn.Year -eq 1)) {
							$tmpEntActualUpdatedOn = $null
						}

						$tmpEntRatedUpdatedOn = $itemEntitlementCapacity.consumption.ratedUpdatedOn

						if (($tmpEntRatedUpdatedOn -is [datetime]) `
								-and ($tmpEntRatedUpdatedOn.Year -eq 1)) {
							$tmpEntRatedUpdatedOn = $null
						}

						$tmpEntConsumedPct = $null

						if ((-Not ($null -eq $tmpEntConsumedRated)) `
								-and ($itemEntitlementCapacity.totalCapacity -gt 0)) {
							$tmpEntConsumedPct = $tmpEntConsumedRated / $itemEntitlementCapacity.totalCapacity * 100
						}

						if ($IncludeConsumption) {
							$itemCapacityEntitlement |
							Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacityEntitlement' `
								-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
							@{ Name = 'CapacityType'; Expression = { $itemEntitlementCapacity.capacityType } },
							'capacitySubType as CapacitySubType',
							@{ Name = 'Units'; Expression = { $itemEntitlementCapacity.capacityUnits } },
							'totalCapacity as TotalCapacity',
							@{ Name = 'MaxNextLifecycleDate'; Expression = { $tmpMaxNextLifecycle } },
							@{ Name = 'LicenseCount'; Expression = { $tmpEntLicenseCount } },
							@{ Name = 'ConsumedActual'; Expression = { $tmpEntConsumedActual } },
							@{ Name = 'ConsumedRated'; Expression = { $tmpEntConsumedRated } },
							@{ Name = 'ConsumedPct'; Expression = { $tmpEntConsumedPct } },
							@{ Name = 'ConsumedActualUpdatedOn'; Expression = { $tmpEntActualUpdatedOn } },
							@{ Name = 'ConsumedRatedUpdatedOn'; Expression = { $tmpEntRatedUpdatedOn } },
							@{ Name = 'Raw'; Expression = { $itemCapacityEntitlement } }

							continue
						}

						$itemCapacityEntitlement |
						Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantCapacityEntitlement' `
							-Property @{ Name = 'PpacTenantId'; Expression = { $tenantId } },
						@{ Name = 'CapacityType'; Expression = { $itemEntitlementCapacity.capacityType } },
						'capacitySubType as CapacitySubType',
						@{ Name = 'Units'; Expression = { $itemEntitlementCapacity.capacityUnits } },
						'totalCapacity as TotalCapacity',
						@{ Name = 'MaxNextLifecycleDate'; Expression = { $tmpMaxNextLifecycle } },
						@{ Name = 'LicenseCount'; Expression = { $tmpEntLicenseCount } },
						@{ Name = 'Raw'; Expression = { $itemCapacityEntitlement } }
					}
				}
			)
		}
		else {
			$colRes = $colSummaryRows
		}

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacTenantCapacity' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}

	end {

	}
}
