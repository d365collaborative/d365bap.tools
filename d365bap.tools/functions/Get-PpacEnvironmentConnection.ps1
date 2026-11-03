<#
    .SYNOPSIS
        List maker connections in a Power Platform environment.

    .DESCRIPTION
        Retrieves the maker connections for an environment through the Power
        Platform API and the Power Platform SDK.

        Each row identifies the connection, the connector it belongs to, the
        account, the status, and the environment.

    .PARAMETER EnvironmentId
        Environment name, GUID, or Power Platform environment identifier.

    .PARAMETER Name
        Connection or connector id, name, or display name filter.

        Wildcards are accepted.

        Default: *

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnection -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Lists the connections in the environment.
        It uses -EnvironmentId to select the environment.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnection -EnvironmentId "00000000-0000-0000-0000-000000000000" -Name "*salesforce*"

        Lists connections that match the filter.
        It uses -EnvironmentId to select the environment.
        It uses -Name to filter on connection or connector details.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentConnection -EnvironmentId "00000000-0000-0000-0000-000000000000" -AsExcelOutput

        Exports the connection inventory to an Excel workbook.
        It uses -EnvironmentId to select the environment.
        It uses -AsExcelOutput to write an Excel file.

    .NOTES
        Author: d365bap.tools contributors
#>
function Get-PpacEnvironmentConnection {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacEnvironmentConnection[]', [object[]])]
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
		$objRoute = Get-PpacConnectivityRoute -EnvironmentId $EnvironmentId

		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$requestUri = 'https://api.powerplatform.com/connectivity/environments/{0}/connections?api-version={1}' `
			-f $objRoute.RouteId,
		$apiVersion

		try {
			$result = Invoke-BapSdkRequest `
				-Resource @{ Builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connections.ConnectionsRequestBuilder' } `
				-Method 'GetAsync' `
				-EnvironmentId $objRoute.RouteId `
				-Token $tokenValue `
				-RequestUrl $requestUri
		}
		catch {
			$messageString = "Failed to retrieve connections from environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important `
				-Message $messageString `
				-Exception $_.Exception

			Stop-PSFFunction -Message "Stopping because the connection request failed." `
				-Exception $_.Exception

			return
		}

		$colItems = @($result.value)
		$colItems = @($colItems |
			Where-Object {
				$connectorName = [string]::IsNullOrWhiteSpace($_.properties.apiId) ? $null : ($_.properties.apiId -split '/')[-1]
				(($_.id -like $Name) `
					-or ($_.id -eq $Name)) `
					-or (($_.name -like $Name) `
						-or ($_.name -eq $Name)) `
					-or (($_.properties.displayName -like $Name) `
						-or ($_.properties.displayName -eq $Name)) `
					-or (($_.properties.apiId -like $Name) `
						-or ($_.properties.apiId -eq $Name)) `
					-or (($connectorName -like $Name) `
						-or ($connectorName -eq $Name))
			})
		$colItems = @($colItems |
			Sort-Object -Property @{ Expression = { $_.properties.displayName } },
			@{ Expression = { $_.name } })

		$colRes = @(
			foreach ($itemRow in $colItems) {
				$tmpStatus = @($itemRow.properties.statuses.status).Where({ $_ }) |
				Sort-Object -Unique

				$itemRow |
				Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentConnection' `
					-Property `
					'id as ConnectionId',
				'name as ConnectionName',
				'properties.displayName as DisplayName',
				'properties.apiId as ConnectorId',
				@{ Name = 'ConnectorName'; Expression = { if (-not [string]::IsNullOrWhiteSpace($_.properties.apiId)) { ($_.properties.apiId -split '/')[-1] } } },
				'properties.accountName as AccountName',
				@{ Name = 'Status'; Expression = { $tmpStatus -join ', ' } },
				'properties.statuses as Statuses',
				@{ Name = 'CreatedBy'; Expression = { if (-not [string]::IsNullOrWhiteSpace($_.properties.createdBy.userPrincipalName)) { $_.properties.createdBy.userPrincipalName } else { $_.properties.createdBy.displayName } } },
				'properties.createdTime as CreatedTime',
				'properties.lastModifiedTime as LastModifiedTime',
				'properties.expirationTime as ExpirationTime',
				'properties.allowSharing as AllowSharing',
				'properties.isSsoConnection as IsSsoConnection',
				'properties.environment.id as EnvironmentId',
				'properties.environment.name as EnvironmentName',
				@{ Name = 'PpacEnvId'; Expression = { $objRoute.RouteId } },
				@{ Name = 'PpacEnvName'; Expression = { $objRoute.RouteName } }
			}
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironmentConnection' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
