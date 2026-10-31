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
	[OutputType('System.Object[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Position = 1)]
		[SupportsWildcards()]
		[string] $Name = '*',

		[Parameter()]
		[switch] $AsExcelOutput
	)

	process {
		if (Test-PSFFunctionInterrupt) { return }

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
		$requestUri = "https://api.powerplatform.com/connectivity/environments/$routeEnvironmentId/connections?api-version=$apiVersion"
		$builder = 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connections.ConnectionsRequestBuilder'

		try {
			$result = Invoke-BapSdkRequest `
				-Resource @{ Builder = $builder } `
				-Method 'GetAsync' `
				-EnvironmentId $routeEnvironmentId `
				-Token $tokenValue `
				-RequestUrl $requestUri
		}
		catch {
			$messageString = "Failed to retrieve connections from environment <c='em'>$EnvironmentId</c>. $($_.Exception.Message)"
			Write-PSFMessage -Level Important -Message $messageString -Exception $_.Exception
			Stop-PSFFunction -Message "Stopping because the connection request failed." -Exception $_.Exception
			return
		}

		if (Test-PSFFunctionInterrupt) { return }

		$items = @($result.value)
		$items = @($items | Where-Object {
				$connectorName = if ([string]::IsNullOrWhiteSpace("$($_.properties.apiId)")) { $null } else { ($_.properties.apiId -split '/')[-1] }
				($_.id -like $Name -or $_.id -eq $Name) `
					-or ($_.name -like $Name -or $_.name -eq $Name) `
					-or ($_.properties.displayName -like $Name -or $_.properties.displayName -eq $Name) `
					-or ($_.properties.apiId -like $Name -or $_.properties.apiId -eq $Name) `
					-or ($connectorName -like $Name -or $connectorName -eq $Name)
			})

		$items = @($items | Sort-Object -Property @{ Expression = { $_.properties.displayName } }, @{ Expression = { $_.name } })

		$resCol = @(
			$items | Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironmentConnection' -Property `
				'id as ConnectionId',
			'name as ConnectionName',
			'properties.displayName as DisplayName',
			'properties.apiId as ConnectorId',
			@{ Name = 'ConnectorName'; Expression = { if (-not [string]::IsNullOrWhiteSpace("$($_.properties.apiId)")) { ($_.properties.apiId -split '/')[-1] } } },
			'properties.accountName as AccountName',
			@{ Name = 'Status'; Expression = { ($_.properties.statuses.status | Where-Object { $_ } | Sort-Object -Unique) -join ', ' } },
			'properties.statuses as Statuses',
			@{ Name = 'CreatedBy'; Expression = { if (-not [string]::IsNullOrWhiteSpace("$($_.properties.createdBy.userPrincipalName)")) { $_.properties.createdBy.userPrincipalName } else { $_.properties.createdBy.displayName } } },
			'properties.createdTime as CreatedTime',
			'properties.lastModifiedTime as LastModifiedTime',
			'properties.expirationTime as ExpirationTime',
			'properties.allowSharing as AllowSharing',
			'properties.isSsoConnection as IsSsoConnection',
			'properties.environment.id as EnvironmentId',
			'properties.environment.name as EnvironmentName'
		)

		foreach ($item in $resCol) {
			$item | Add-Member -NotePropertyName PpacEnvId -NotePropertyValue $routeEnvironmentId -Force
			$item | Add-Member -NotePropertyName PpacEnvName -NotePropertyValue $routeEnvironmentName -Force
		}

		if ($AsExcelOutput) {
			if ($resCol.Count -gt 0) {
				$resCol | Export-Excel -WorksheetName 'Get-PpacEnvironmentConnection' `
					-WarningAction SilentlyContinue
			}
			return
		}

		$resCol
	}
}
