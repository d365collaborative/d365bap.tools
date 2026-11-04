<#
    .SYNOPSIS
        Requests temporary SQL credentials for one unified environment.

    .DESCRIPTION
        Requests JIT SQL access from Dataverse and waits for backend propagation.
        Credentials are returned in memory. Nothing is stored in CredentialManager or the SSMS cache.

    .PARAMETER EnvironmentId
        Environment name or GUID. Wildcards must match exactly one unified environment.

    .PARAMETER WhitelistIp
        SQL firewall IP, range, or CIDR. Loopback discovers the public IP.

        Default: 127.0.0.1.

    .PARAMETER Role
        SQL access role. Writer permits data changes.

        Default: Reader.

    .PARAMETER Reason
        Audit reason for requesting SQL access.

        Default: Administrative access via d365bap.tools.

    .PARAMETER WaitSeconds
        Propagation wait in seconds before returning credentials. Zero skips the wait.

        Default: 60.

    .PARAMETER AsExcelOutput
        Exports credentials, including the password, to Excel instead of returning them in memory.

    .EXAMPLE
        PS C:\> $jit = Get-UdeDbJit -EnvironmentId "dev-environment"

        Requests temporary read access without caching credentials.
        It uses -EnvironmentId to select exactly one environment.
        It uses the default -WhitelistIp to discover the public IP.
        It uses the default -Role Reader.
        It uses the default -Reason Administrative access via d365bap.tools.
        It uses the default -WaitSeconds 60 for backend propagation.
        It leaves -AsExcelOutput disabled by default and returns credentials in memory.

    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "dev-environment" -Role Writer -WhitelistIp "203.0.113.10" -Reason "Approved migration" -WaitSeconds 0

        Requests write access with explicit firewall and audit settings.
        It uses -EnvironmentId to select exactly one environment.
        It uses -Role Writer to allow data changes.
        It uses -WhitelistIp to allow the specified IP.
        It uses -Reason for the access audit record.
        It uses -WaitSeconds 0; the caller must allow propagation before connecting.
        It leaves -AsExcelOutput disabled by default and returns credentials in memory.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeDbJit {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.UdeDatabaseJit[]')]
	param (
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('PpacEnvId')]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[ValidateNotNullOrEmpty()]
		[string] $WhitelistIp = '127.0.0.1',

		[ValidateSet('Reader', 'Writer')]
		[string] $Role = 'Reader',

		[ValidateNotNullOrEmpty()]
		[string] $Reason = 'Administrative access via d365bap.tools',

		[ValidateRange(0, [int]::MaxValue)]
		[int] $WaitSeconds = 60,

		[switch] $AsExcelOutput
	)

	process {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId
		$colEnvironments = @($envObj |
			Where-Object FinOpsMetadataEnvType -EQ 'Internal')

		if ($colEnvironments.Count -ne 1) {
			throw "Expected exactly one unified environment for '$EnvironmentId'; found $($colEnvironments.Count). Use a specific name or GUID."
		}

		if ($WhitelistIp -eq '127.0.0.1') {
			$WhitelistIp = ([string](Invoke-RestMethod -Uri 'https://icanhazip.com')).Trim()
			$publicIp = $null
			if ((-not [Net.IPAddress]::TryParse($WhitelistIp, [ref]$publicIp)) `
					-or ([Net.IPAddress]::IsLoopback($publicIp))) {
				throw 'Could not determine a public IP address. Specify -WhitelistIp explicitly.'
			}
		}

		$baseUri = $colEnvironments[0].PpacEnvUri.TrimEnd('/') + '/'
		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenWebApiValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			Authorization  = "Bearer $tokenWebApiValue"
			Accept         = 'application/json'
			'Content-Type' = 'application/json; charset=utf-8'
		}
		$localUri = $baseUri + 'api/data/v9.2/msprov_getfinopssqljitaccessasync'
		$payload = @{
			sqljitclientipaddress = $WhitelistIp
			sqljitreason          = $Reason
			sqljitrole            = $Role
		} | ConvertTo-Json -Depth 3

		$objResponse = Invoke-RestMethod -Method Post `
			-Uri $localUri `
			-Headers $hashHeaders `
			-Body $payload

		$expiration = [DateTimeOffset]$objResponse.sqljitexpiration
		if ($WaitSeconds -gt 0) {
			Write-PSFMessage -Level Verbose `
				-Message "Waiting $WaitSeconds seconds for the JIT credentials to propagate."

			Start-Sleep -Seconds $WaitSeconds
		}

		$colResults = @($objResponse |
			Select-PSFObject -TypeName 'D365Bap.Tools.UdeDatabaseJit' `
				-ExcludeProperty '@odata.context' `
				-Property 'servername as Server',
			'databasename as Database',
			'sqljitusername as Username',
			'sqljitpassword as Password',
			@{ Name = 'Expiration'; Expression = { $expiration.UtcDateTime } },
			@{ Name = 'ExpirationIso'; Expression = { $expiration.ToString('o') } },
			'sqljitrole as Role',
			@{ Name = 'EnvironmentId'; Expression = { $colEnvironments[0].PpacEnvId } },
			*)

		if ($AsExcelOutput) {
			$colResults |
			Export-Excel -WorksheetName 'Get-UdeDbJit'
			return
		}

		$colResults
	}
}
