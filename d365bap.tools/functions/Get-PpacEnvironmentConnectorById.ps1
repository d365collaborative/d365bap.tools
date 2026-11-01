<#
    .SYNOPSIS
        Get one connector from a Power Platform environment.

    .DESCRIPTION
        Retrieves one connector by id from an environment through the Power
        Platform API and the Power Platform SDK.

        The connector id can be the short name or the full resource id.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER ConnectorId
        Connector short name or full connector resource id.

    .PARAMETER IncludeUnavailable
        Includes a connector that is not available in the environment but is
        governable by policy.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnectorById -EnvironmentId "00000000-0000-0000-0000-000000000000" -ConnectorId "shared_office365"

        Returns the Office 365 Outlook connector.
        It uses -EnvironmentId to select the environment.
        It uses -ConnectorId to select the connector.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnectorById -EnvironmentId "00000000-0000-0000-0000-000000000000" -ConnectorId "shared_office365" -IncludeUnavailable

        Returns the connector even when it is not available in the environment.
        It uses -EnvironmentId to select the environment.
        It uses -ConnectorId to select the connector.
        It uses -IncludeUnavailable to include unavailable connectors.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentConnectorById {
	[CmdletBinding()]
	[OutputType('System.Object')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $ConnectorId,

		[switch] $IncludeUnavailable
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$route = Get-PpacConnectivityRoute -EnvironmentId $EnvironmentId
		if ($null -eq $route) {
			$messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		$secureToken = Get-BapAccessToken -ResourceUrl 'https://api.powerplatform.com/'
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$filter = [uri]::EscapeDataString("environment eq '$($route.RouteId -replace "'", "''")'")
		$connectorKey = ($ConnectorId -split '/')[-1]
		$requestUri = "https://api.powerplatform.com/connectivity/environments/$($route.RouteId)/connectors/$([uri]::EscapeDataString($connectorKey))?`$filter=$filter&api-version=$apiVersion"

		if ($IncludeUnavailable) { $requestUri += '&showAllDlpEnforceableApis=true' }

		try {
			$result = Invoke-BapSdkRequest `
				-Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.Item.WithConnectorItemRequestBuilder' } `
				-Method 'GetAsync' `
				-EnvironmentId $route.RouteId `
				-Token $tokenValue `
				-RequestUrl $requestUri
		}
		catch {
			$messageString = "Failed to retrieve connector <c='em'>$ConnectorId</c> from environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the connector request failed." -Exception $_.Exception
			return
		}

		if ($null -eq $result) { return }

		$result | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentConnector' -Property `
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
		@{ Name = 'PpacEnvId'; Expression = { $route.RouteId } },
		@{ Name = 'PpacEnvName'; Expression = { $route.RouteName } }
	}
}
