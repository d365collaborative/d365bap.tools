<#
    .SYNOPSIS
        List the tenant connector catalog.

    .DESCRIPTION
        Retrieves the tenant-wide connector catalog that DLP and advanced
        connector policies can govern.

        The default environment is used as the catalog anchor.

    .PARAMETER Name
        Connector id, name, or display name filter. Wildcards are accepted.

        Default: *

    .PARAMETER ConnectorId
        Returns one connector by its short name or full resource id.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacTenantConnector

        Lists the tenant connector catalog.

    .EXAMPLE
        PS C:\> Get-PpacTenantConnector -Name "*sql*"

        Lists connectors that match the filter.
        It uses -Name to filter on connector id, name, or display name.

    .EXAMPLE
        PS C:\> Get-PpacTenantConnector -ConnectorId "shared_office365"

        Returns one connector from the tenant catalog.
        It uses -ConnectorId to select the connector.

    .EXAMPLE
        PS C:\> Get-PpacTenantConnector -AsExcelOutput

        Exports the tenant connector catalog to an Excel workbook.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacTenantConnector {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[SupportsWildcards()]
		[string] $Name = '*',

		[ValidateNotNullOrEmpty()]
		[string] $ConnectorId,

		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		if ($PSBoundParameters.ContainsKey('ConnectorId') -and $PSBoundParameters.ContainsKey('Name')) {
			Stop-PSFFunction -Message "Specify -Name or -ConnectorId, not both."
			return
		}

		$tenantId = $null
		try { $tenantId = (Get-BapContext).TenantId } catch { $tenantId = $null }
		if ([string]::IsNullOrWhiteSpace("$tenantId")) {
			Stop-PSFFunction -Message "Could not resolve the current tenant id."
			return
		}

		$routeId = "Default-$tenantId"
		$secureToken = Get-BapAccessToken -ResourceUrl 'https://api.powerplatform.com/'
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$filter = [uri]::EscapeDataString("environment eq '$routeId'")
		$isItemLookup = $PSBoundParameters.ContainsKey('ConnectorId')

		if ($isItemLookup) {
			$connectorKey = ($ConnectorId -split '/')[-1]
			$requestUri = "https://api.powerplatform.com/connectivity/environments/$routeId/connectors/$([uri]::EscapeDataString($connectorKey))?`$filter=$filter&api-version=$apiVersion&showAllDlpEnforceableApis=true"
			$builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.Item.WithConnectorItemRequestBuilder'
		}
		else {
			$requestUri = "https://api.powerplatform.com/connectivity/environments/$routeId/connectors?`$filter=$filter&api-version=$apiVersion&showAllDlpEnforceableApis=true"
			$builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.ConnectorsRequestBuilder'
		}

		try {
			$result = Invoke-BapSdkRequest `
				-Resource @{ Builder = $builder } `
				-Method 'GetAsync' `
				-EnvironmentId $routeId `
				-Token $tokenValue `
				-RequestUrl $requestUri
		}
		catch {
			$messageString = "Failed to retrieve the tenant connector catalog. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the connector request failed." -Exception $_.Exception
			return
		}

		if ($isItemLookup) {
			$items = @($result)
		}
		else {
			$items = @($result.value)
			$items = @($items | Where-Object {
					($_.id -like $Name -or $_.id -eq $Name) `
						-or ($_.name -like $Name -or $_.name -eq $Name) `
						-or ($_.properties.displayName -like $Name -or $_.properties.displayName -eq $Name)
				})
		}

		$items = @($items | Sort-Object -Property @{ Expression = { $_.properties.displayName } }, @{ Expression = { $_.name } })

		$resCol = @(
			$items | Select-PSFObject -TypeName 'D365Bap.Tools.PpacTenantConnector' -Property `
				'id as ConnectorId',
			'name as ConnectorName',
			'properties.displayName as DisplayName',
			'properties.publisher as Publisher',
			'properties.tier as Tier',
			'properties.releaseTag as ReleaseTag',
			'properties.isCustomApi as IsCustomApi',
			'properties.apiEnvironment as ApiEnvironment',
			@{ Name = 'Capabilities'; Expression = { $_.properties.capabilities -join ', ' } },
			'properties.createdTime as CreatedTime',
			'properties.changedTime as ChangedTime',
			'properties.description as Description',
			@{ Name = 'PpacTenantId'; Expression = { $tenantId } }
		)

		if ($AsExcelOutput) {
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacTenantConnector' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
