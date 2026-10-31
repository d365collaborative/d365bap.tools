<#
    .SYNOPSIS
        List connectors in a Power Platform environment.

    .DESCRIPTION
        Retrieves the connector catalog for an environment through the Power
        Platform API and the Power Platform SDK.

        The list contains the connectors available in the environment. The
        catalog can be expanded to every connector that policy can govern.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER Name
        Connector id, name, or display name filter. Wildcards are accepted.

        Default: *

    .PARAMETER ConnectorId
        Returns one connector by its short name or full resource id.

    .PARAMETER IncludeUnavailable
        Includes connectors not available in the environment but governable by policy.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the connectors available in the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000" -ConnectorId "shared_office365"

        Returns one connector from the environment.
        It uses -EnvironmentId to select the environment.
        It uses -ConnectorId to select the connector.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000" -Name "*sql*"

        Lists connectors that match the filter.
        It uses -EnvironmentId to select the environment.
        It uses -Name to filter on connector id, name, or display name.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000" -IncludeUnavailable

        Lists every connector that policy can govern.
        It uses -EnvironmentId to select the environment.
        It uses -IncludeUnavailable to include unavailable connectors.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports the connector inventory to an Excel workbook.
        It uses -EnvironmentId to select the environment.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentConnector {
	[CmdletBinding(DefaultParameterSetName = 'ByEnvironment')]
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(ParameterSetName = 'ByEnvironment', Position = 1)]
		[SupportsWildcards()]
		[string] $Name = '*',

		[Parameter(ParameterSetName = 'ByConnectorId', Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ConnectorId,

		[Parameter()]
		[switch] $IncludeUnavailable,

		[Parameter()]
		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		# Resolve the environment. Get-BapEnvironment does not always return
		# the default environment, so fall back to the connectivity route name.
		$envObj = Get-BapEnvironment `
			-EnvironmentId $EnvironmentId | `
			Select-Object -First 1

		if ($null -ne $envObj) {
			$routeEnvironmentId = $envObj.PpacEnvId
			$routeEnvironmentName = $envObj.PpacEnvName
		}
		else {
			$routeEnvironmentId = $null
			$routeEnvironmentName = $EnvironmentId

			if ($EnvironmentId -match '^Default-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
				$routeEnvironmentId = $EnvironmentId
			}
			else {
				$environmentGuid = [guid]::Empty
				if ([guid]::TryParse($EnvironmentId, [ref]$environmentGuid)) {
					$tenantId = $null
					try {
						$tenantId = (Get-BapContext).TenantId
					}
					catch {
						$tenantId = $null
					}

					if (-not [string]::IsNullOrWhiteSpace("$tenantId") -and $environmentGuid -eq [guid]$tenantId) {
						$routeEnvironmentId = "Default-$tenantId"
					}
					else {
						$routeEnvironmentId = "$environmentGuid"
					}
				}
			}
		}

		if ([string]::IsNullOrWhiteSpace("$routeEnvironmentId")) {
			$messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		$secureToken = Get-BapAccessToken -ResourceUrl 'https://api.powerplatform.com/'
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$filter = [uri]::EscapeDataString("environment eq '$($routeEnvironmentId -replace "'", "''")'")

		$isItemLookup = $PSCmdlet.ParameterSetName -eq 'ByConnectorId'
		if ($isItemLookup) {
			$connectorKey = ($ConnectorId -split '/')[-1]
			$requestUri = "https://api.powerplatform.com/connectivity/environments/$routeEnvironmentId/connectors/$([uri]::EscapeDataString($connectorKey))" + "?`$filter=$filter" + "&api-version=$apiVersion"
			$builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.Item.WithConnectorItemRequestBuilder'
		}
		else {
			$requestUri = "https://api.powerplatform.com/connectivity/environments/$routeEnvironmentId/connectors" + "?`$filter=$filter" + "&api-version=$apiVersion"
			$builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.ConnectorsRequestBuilder'
		}

		if ($IncludeUnavailable) {
			$requestUri += '&showAllDlpEnforceableApis=true'
		}

		try {
			$result = Invoke-BapSdkRequest `
				-Resource @{ Builder = $builder } `
				-Method 'GetAsync' `
				-EnvironmentId $routeEnvironmentId `
				-Token $tokenValue `
				-RequestUrl $requestUri
		}
		catch {
			$messageString = "Failed to retrieve connectors from environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the connector request failed." -Exception $_.Exception
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

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
			$items | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentConnector' -Property `
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
			'properties.description as Description'
		)

		foreach ($item in $resCol) {
			$item | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $routeEnvironmentId -Force
			$item | Add-Member -NotePropertyName PpacEnvName -NotePropertyValue $routeEnvironmentName -Force
		}

		if ($AsExcelOutput) {
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacEnvironmentConnector' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
