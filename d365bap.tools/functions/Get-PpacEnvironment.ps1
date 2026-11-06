<#
    .SYNOPSIS
        Retrieves environments through the Power Platform API.

    .DESCRIPTION
        Lists environments by GUID or wildcard through paged discovery.
        Discovery needs the Power Platform Administrator role and a token
        covering that API area, else it warns and yields nothing. See
        Get-BapEnvironment.

    .PARAMETER EnvironmentId
        Environment GUID or display name wildcard. GUIDs use a direct request.

        Default: *

    .PARAMETER AsExcelOutput
        Exports matching environments to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-PpacEnvironment

        Lists environments accessible to the current identity.

    .EXAMPLE
        PS C:\> Get-PpacEnvironment -EnvironmentId "00000000-0000-0000-0000-000000000000"

        Retrieves the environment directly by GUID.
        It uses -EnvironmentId to avoid a tenant-wide discovery request.

    .EXAMPLE
        PS C:\> Get-PpacEnvironment -EnvironmentId "*Demo*" -AsExcelOutput

        Exports environments whose names match the filter.
        It uses -EnvironmentId to filter names.
        It uses -AsExcelOutput to write a workbook.

    .NOTES
        Author: d365bap.tools contributors

    .LINK
        https://learn.microsoft.com/en-us/rest/api/power-platform/environmentmanagement/environments/list-environments-for-user

    .LINK
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2
#>
function Get-PpacEnvironment {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.PpacEnvironment[]', [object[]])]
	param (
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[SupportsWildcards()]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId = '*',

		[switch] $AsExcelOutput
	)

	process {
		$objSecureToken = Get-BapAccessToken -PowerPlatform
		$tokenValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$apiVersion = $script:BapApiVersions.PowerPlatform
		$parsedId = [guid]::Empty
		$isEnvironmentId = [guid]::TryParse($EnvironmentId, [ref]$parsedId)
		$builderName = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Environments.EnvironmentsRequestBuilder'
		$requestUri = 'https://api.powerplatform.com/environmentmanagement/environments?api-version={0}' `
			-f $apiVersion

		if ($isEnvironmentId) {
			$builderName = 'Microsoft.PowerPlatform.Management.Environmentmanagement.Environments.Item.EnvironmentItemRequestBuilder'
			$requestUri = 'https://api.powerplatform.com/environmentmanagement/environments/{0}?api-version={1}' `
				-f $parsedId,
			$apiVersion
		}

		try {
			$colEnvironments = @(
				do {
					$result = Invoke-BapSdkRequest `
						-Resource @{ Builder = $builderName } `
						-Method 'GetAsync' `
						-Token $tokenValue `
						-RequestUrl $requestUri

					if ($isEnvironmentId) {
						$result
						$requestUri = $null
					}
					else {
						$result.value
						$requestUri = $result.'@odata.nextLink'
					}
				} while (-not [string]::IsNullOrWhiteSpace($requestUri))
			)
		}
		catch {
			$errorText = "$($_.Exception.Message) $($_.Exception.InnerException.Message)"

			if ($errorText -match '403|Forbidden') {
				$messageString = "Use Get-BapEnvironment to discover environments instead. The Power Platform environment management API denied access (HTTP 403). Discovery needs the Power Platform Administrator tenant role. For now - use Get-BapEnvironment to discover environments instead."
				Write-PSFMessage -Level Warning `
					-Message $messageString

				return
			}

			throw
		}

		$colRes = @(
			$colEnvironments |
			Where-Object {
				($isEnvironmentId) `
					-or ($_.id -like $EnvironmentId) `
					-or ($_.displayName -like $EnvironmentId)
			} | Sort-Object -Property displayName |
			Select-PSFObject -TypeName 'D365Bap.Tools.PpacEnvironment' `
				-Property 'id as PpacEnvId',
			'id as EnvId',
			'displayName as PpacEnvName',
			'displayName as EnvName',
			'type as Sku',
			'finOpsMetadata.type as EnvType',
			@{ Name = 'Managed'; Expression = { $_.protectionLevel -eq 'Standard' } },
			*
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName 'Get-PpacEnvironment' `
				-WarningAction SilentlyContinue

			return
		}

		$colRes
	}
}
