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

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the connectors available in the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000" -Name "*sql*"

        Lists connectors that match the filter.
        It uses -EnvironmentId to select the environment.
        It uses -Name to filter on connector id, name, or display name.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnector -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports the connector inventory to an Excel workbook.
        It uses -EnvironmentId to select the environment.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentConnector {
	[CmdletBinding()]
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $Name = '*',

		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$route = Get-PpacConnectivityRoute -EnvironmentId $EnvironmentId
		if ($null -eq $route) {
			$messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-Environment</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		$secureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
		$apiVersion = if ([string]::IsNullOrWhiteSpace("$script:BapSdkApiVersion")) { '2024-10-01' } else { $script:BapSdkApiVersion }
		$filter = [uri]::EscapeDataString("environment eq '$($route.RouteId -replace "'", "''")'")
		$requestUri = "https://api.powerplatform.com/connectivity/environments/$($route.RouteId)/connectors?`$filter=$filter&api-version=$apiVersion"

		try {
			$result = Invoke-BapSdkRequest `
				-Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.ConnectorsRequestBuilder' } `
				-Method 'GetAsync' `
				-EnvironmentId $route.RouteId `
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

		$colItems = @($result.value)
		$colItems = @($colItems | Where-Object {
				($_.id -like $Name -or $_.id -eq $Name) `
					-or ($_.name -like $Name -or $_.name -eq $Name) `
					-or ($_.properties.displayName -like $Name -or $_.properties.displayName -eq $Name)
			})
		$colItems = @($colItems | Sort-Object -Property @{ Expression = { $_.properties.displayName } }, @{ Expression = { $_.name } })

		$colRes = @(
			$colItems | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentConnector' -Property `
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
		)

		if ($AsExcelOutput) {
			if ($colRes.Count -gt 0) {
				$colRes | Export-Excel -WorksheetName 'Get-PpacEnvironmentConnector' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$colRes
	}
}
