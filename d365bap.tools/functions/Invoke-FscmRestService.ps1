<#
    .SYNOPSIS
        Invokes a REST service operation in Finance and Supply Chain Management (FSCM).

    .DESCRIPTION
        Sends an authenticated request to a custom service operation in
        Finance and Operations and returns the response object.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Endpoint
        Service operation path in the form ServiceGroup/Service/Operation.

    .PARAMETER Method
        HTTP method used for the call: Get or Post.

        Default: Post

    .PARAMETER Payload
        Raw JSON request body sent with a POST call.

    .EXAMPLE
        PS C:\> Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetData"

        Calls the operation with the default POST method and no payload.
        It uses -EnvironmentId to select the target environment.
        It uses -Endpoint to address the service operation.
        It uses the default -Method Post to send a POST request.

    .EXAMPLE
        PS C:\> Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetData" -Method Get

        Calls the operation with a GET request.
        It uses -EnvironmentId to select the target environment.
        It uses -Endpoint to address the service operation.
        It uses -Method Get to send a GET request.

    .EXAMPLE
        PS C:\> $payload = '{"_contract": {"CustomerAccount": "US-001"}}'
        PS C:\> Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetCustomer" -Payload $payload

        Sends a structured JSON payload with the default POST method.
        It uses -EnvironmentId to select the target environment.
        It uses -Endpoint to address the service operation.
        It uses -Payload $payload to send the request body.
        It uses the default -Method Post to send a POST request.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-FscmRestService {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Endpoint,

		[ValidateSet('Get', 'Post')]
		[string] $Method = 'Post',

		[string] $Payload
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeadersFnO = @{
			"Authorization" = "Bearer $($tokenFnoOdataValue)"
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$localUri = '{0}/api/services/{1}' `
			-f $baseUri,
		$Endpoint
		$resStatusCode = $null

		$hashParms = @{
			Method             = $Method
			Uri                = $localUri
			Headers            = $hashHeadersFnO
			StatusCodeVariable = 'resStatusCode'
			SkipHttpErrorCheck = $true
		}

		if ($Method -eq 'Post') {
			$hashParms.ContentType = 'application/json;charset=utf-8'

			if (-not [string]::IsNullOrEmpty($Payload)) {
				$hashParms.Body = $Payload
			}
		}

		$resService = Invoke-RestMethod @hashParms

		if (-not "$resStatusCode" -like "2*") {
			$messageString = "Invoking the FSCM REST service endpoint <c='em'>$Endpoint</c> failed with status code <c='em'>$resStatusCode</c>."
			Write-PSFMessage -Level Warning `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the REST service call failed." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$resService
	}

	end {

	}
}
