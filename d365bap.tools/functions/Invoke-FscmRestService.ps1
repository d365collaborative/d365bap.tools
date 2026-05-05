<#
    .SYNOPSIS
        Invokes a REST service operation in Finance and Supply Chain Management (FSCM).

    .DESCRIPTION
        Calls a custom service operation exposed via the FSCM REST services endpoint (/api/services).

        The caller supplies the full service path (ServiceGroup/Service/Operation) as the Endpoint,
        and an optional pre-structured JSON payload for POST operations.

    .PARAMETER EnvironmentId
        The id of the environment you want to target.

        This can be obtained from the Get-BapEnvironment cmdlet.

    .PARAMETER Endpoint
        The full path to the service operation, in the format: ServiceGroup/Service/Operation.

        E.g. MyServiceGroup/MyService/MyOperation

    .PARAMETER Method
        The HTTP method to use when calling the service operation.

        Valid values are: Get, Post

        Defaults to: Post

    .PARAMETER Payload
        The raw JSON payload to send with a POST request, fully structured as expected by the service operation.

        Not required for GET requests.

    .EXAMPLE
        PS C:\> Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetData"

        This will call the GetData operation using the default POST method, without a payload.

    .EXAMPLE
        PS C:\> $payload = '{"_contract": {"CustomerAccount": "US-001"}}'
        PS C:\> Invoke-FscmRestService -EnvironmentId "eec2c631-a74f-4f7c-b5a4-67d0ee4c0b3c" -Endpoint "MyServiceGroup/MyService/GetCustomer" -Payload $payload

        This will call the GetCustomer operation using POST and pass the structured JSON payload to the service.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-FscmRestService {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter(Mandatory = $true)]
        [string] $Endpoint,

        [ValidateSet('Get', 'Post')]
        [string] $Method = 'Post',

        [string] $Payload
    )

    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + "/api/services/$Endpoint"
        $resStatusCode = $null

        $parms = @{
            Method              = $Method
            Uri                 = $localUri
            Headers             = $headersFnO
            StatusCodeVariable  = 'resStatusCode'
            SkipHttpErrorCheck  = $true
        }

        if ($Method -eq 'Post') {
            $parms.ContentType = 'application/json;charset=utf-8'

            if (-not [string]::IsNullOrEmpty($Payload)) {
                $parms.Body = $Payload
            }
        }

        $resService = Invoke-RestMethod @parms

        if (-not "$resStatusCode" -like "2*") {
            $messageString = "Invoking the FSCM REST service endpoint <c='em'>$Endpoint</c> failed with status code <c='em'>$resStatusCode</c>."
            Write-PSFMessage -Level Warning -Message $messageString
            Stop-PSFFunction -Message "Stopping because the REST service call failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $resService
    }

    end {

    }
}
