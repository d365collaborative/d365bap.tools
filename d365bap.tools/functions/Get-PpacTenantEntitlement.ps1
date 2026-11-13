
<#
    .SYNOPSIS
        Get tenant licensing entitlements.

    .DESCRIPTION
        Retrieves Power Platform licensing entitlements, including consumed
        capacity, pay-as-you-go usage, and backing licenses.

    .PARAMETER EntitlementId
        Entitlement id filter. Wildcards are accepted; expansion misses skip quietly.

        Default: *

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacTenantEntitlement

        Lists every tenant licensing entitlement.

    .EXAMPLE
        PS C:\> Get-PpacTenantEntitlement -EntitlementId "AI"

        Returns the AI licensing entitlement.
        It uses -EntitlementId to select the entitlement.

    .EXAMPLE
        PS C:\> Get-PpacTenantEntitlement -EntitlementId "Power*"

        Lists entitlements matching the filter.
        It uses -EntitlementId to filter on the entitlement id.

    .EXAMPLE
        PS C:\> Get-PpacTenantEntitlement -AsExcelOutput

        Exports tenant licensing entitlements to an Excel workbook.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacTenantEntitlement {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacTenantEntitlement[]', [object[]])]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string[]] $EntitlementId = '*',

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

		$colPatterns = @($EntitlementId)

		$colWildcardPatterns = @(
			$colPatterns |
			Where-Object { [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($_) }
		)

		$colKnownIds = @()

		if ($colWildcardPatterns.Count -gt 0) {
			$reportRequestUri = 'https://api.powerplatform.com/licensing/tenantCapacity/currencyReports?api-version={0}' `
				-f $apiVersion

			try {
				$objReport = Invoke-RestMethod `
					-Method Get `
					-Uri $reportRequestUri `
					-Headers $hashHeaders 4> $null
			}
			catch {
				$messageString = "Failed retrieving tenant currency reports. $($_.Exception.Message)"
				Write-PSFMessage -Level Important `
					-Message $messageString `
					-Exception $_.Exception

				Stop-PSFFunction -Message 'Stopping because the currency report request failed.' `
					-Exception $_.Exception

				return
			}

			if ($objReport -is [array]) {
				$colReportEntries = @($objReport)
			}
			else {
				$colReportEntries = @($objReport.value)
			}

			$colKnownIds = @(
				$colReportEntries |
				ForEach-Object { $_.currencyType } |
				Where-Object { $_ } |
				Sort-Object -Unique
			)
		}

		$colTargetIds = @(
			foreach ($itemPattern in $colPatterns) {
				if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($itemPattern)) {
					$tmpMatchedIds = @(
						$colKnownIds |
						Where-Object { $_ -like $itemPattern }
					)

					if ($tmpMatchedIds.Count -eq 0) {
						$messageString = "No licensing entitlement matches pattern '<c='em'>$itemPattern</c>'. Skipping."
						Write-PSFMessage -Level Warning `
							-Message $messageString
					}

					foreach ($itemMatchedId in $tmpMatchedIds) {
						$itemMatchedId
					}
				}
				else {
					$itemPattern
				}
			}
		)

		$colTargetIds = @(
			$colTargetIds |
			Sort-Object -Unique
		)

		$colExplicitIds = @(
			$colPatterns |
			Where-Object { -Not [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($_) }
		)

		$colPayloads = @(
			foreach ($itemTargetId in $colTargetIds) {
				$requestUri = 'https://api.powerplatform.com/licensing/entitlements/{0}?api-version={1}' `
					-f [uri]::EscapeDataString($itemTargetId),
				$apiVersion

				try {
					$tmpPayload = Invoke-RestMethod `
						-Method Get `
						-Uri $requestUri `
						-Headers $hashHeaders 4> $null
				}
				catch {
					$statusCode = 0
					try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch { $statusCode = 0 }

					if ($statusCode -eq 404) {
						if ($itemTargetId -in $colExplicitIds) {
							$messageString = "No licensing entitlement found for '<c='em'>$itemTargetId</c>'. Skipping."
							Write-PSFMessage -Level Warning `
								-Message $messageString

							continue
						}

						$messageString = "No licensing entitlement found for '<c='em'>$itemTargetId</c>'. Skipping."
						Write-PSFMessage -Level Verbose `
							-Message $messageString

						continue
					}

					$messageString = "Failed retrieving licensing entitlement for '<c='em'>$itemTargetId</c>'."
					Write-PSFMessage -Level Warning `
						-Message $messageString `
						-ErrorRecord $_

					Stop-PSFFunction -Message 'Stopping because the entitlement request failed.' `
						-ErrorRecord $_

					return
				}

				if ($null -eq $tmpPayload) { continue }

				$tmpPayload
			}
		)

		$colRes = @(
			foreach ($itemPayload in $colPayloads) {
				$tmpLicenses = @(
					$itemPayload.entitlement.capacity.licenses |
					Where-Object { $_ }
				)
				$tmpLicenseCount = $tmpLicenses.Count

				$tmpCategoryList = @(
					$itemPayload.productCategories |
					Where-Object { $_ }
				)
				$tmpProductCategories = $tmpCategoryList -join ', '

				$tmpEntitled = $itemPayload.entitlement.capacity.entitled.value
				$tmpConsumed = $itemPayload.entitlement.capacity.consumed.value

				$tmpLeft = $null

				if (-Not ($null -eq $tmpEntitled)) {
					if ($null -eq $tmpConsumed) {
						$tmpLeft = $tmpEntitled
					}
					else {
						$tmpLeft = $tmpEntitled - $tmpConsumed
					}
				}

				$itemPayload |
				Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantEntitlement' `
					-Property `
					'entitlementId as EntitlementId',
				'entitlement.unit as EntitlementUnit',
				'entitlement.capacity.unit as CapacityUnit',
				'entitlement.capacity.entitled.value as Entitled',
				'entitlement.capacity.consumed.value as Consumed',
				'entitlement.capacity.consumed.consumptionType as ConsumptionType',
				'entitlement.capacity.consumed.lastUpdatedOn as LastUpdatedOn',
				'entitlement.capacity.consumed.writeOff as WriteOff',
				'entitlement.capacity.allocated.value as Allocated',
				'entitlement.capacity.allocated.autoAllocated as AutoAllocated',
				'entitlement.capacity.availableQuantity as Available',
				@{ Name = 'Left'; Expression = { $tmpLeft } },
				'entitlement.capacity.status as Status',
				@{ Name = 'Licenses'; Expression = { $tmpLicenseCount } },
				@{ Name = 'ProductCategories'; Expression = { $tmpProductCategories } },
				'entitlement.payGo.entitled.value as PayGoEntitled',
				'entitlement.payGo.consumed.value as PayGoConsumed',
				'entitlement.payGo.consumed.consumptionType as PayGoConsumptionType',
				@{ Name = 'Raw'; Expression = { $itemPayload } }
			}
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacTenantEntitlement' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}

	end {

	}
}
