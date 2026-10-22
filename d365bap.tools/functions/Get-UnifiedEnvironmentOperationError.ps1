
<#
    .SYNOPSIS
        Get Finance and Operations operation errors for a Unified environment.
        
    .DESCRIPTION
        Enables the user to retrieve recent Finance and Operations operation errors for a Unified environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER MaxResults
        The maximum number of operation errors to return.
        
        Default it 20.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentOperationError -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will fetch up to 20 recent operation errors for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentOperationError -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -MaxResults 100
        
        This will fetch up to 100 recent operation errors for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentOperationError -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
        
        This will fetch recent operation errors for the specified environment.
        It will output the results directly into an Excel file, that will automatically open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UnifiedEnvironmentOperationError {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [ValidateRange(1, 1000)]
        [int] $MaxResults = 20,

        [switch] $AsExcelOutput
    )
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-UnifiedEnvironment `
            -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $secureToken = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            "Authorization" = "Bearer $($tokenValue)"
        }

        $localUri = "https://api.powerplatform.com/dynamics/environments/{0}/operationerrors?api-version=2024-10-01&maxResults={1}" `
            -f $envObj.PpacEnvId, $MaxResults

        $response = Invoke-RestMethod -Uri $localUri `
            -Method Get `
            -Headers $headers

        $colErrors = @($response.errors)

        $resCol = @(
            $colErrors | Select-PSFObject -TypeName 'D365Bap.Tools.UnifiedEnvironmentOperationError' `
                -Property "correlationId As CorrelationId",
            "operationType As OperationType",
            "errorCode As ErrorCode",
            "errorMessage As ErrorMessage",
            "failedActionName As FailedActionName",
            "failedAt As FailedAt",
            @{ Name = "EnvironmentId"; Expression = { $envObj.PpacEnvId } },
            @{ Name = "EnvironmentName"; Expression = { $envObj.PpacEnvName } }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel `
                -WorksheetName "Get-UnifiedEnvironmentOperationError" `
                -WarningAction SilentlyContinue
            
            return
        }

        $resCol
    }

    end {
    }
}