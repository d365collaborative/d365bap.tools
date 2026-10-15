
<#
    .SYNOPSIS
        Apply a D365 Finance and Operations version to the environment.
        
    .DESCRIPTION
        Applies the specified D365 Finance and Operations application version to the environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Version
        The version of D365 Finance and Operations to apply.

        A full application version is expected (e.g. "10.0.47.5"), but a short platform
        version (e.g. "10.0.47") is also accepted.
        
    .PARAMETER WaitForCompletion
        Instructs the cmdlet to wait until the apply operation reaches a terminal state.
        
    .EXAMPLE
        PS C:\> Invoke-PpacD365VersionUpdate -EnvironmentId "env-123" -Version "10.0.47.5"
        
        This will queue the update to D365 Finance and Operations version 10.0.47.5 for the specified environment.
        It returns immediately with the operationId / resourceId.
        
    .EXAMPLE
        PS C:\> Invoke-PpacD365VersionUpdate -EnvironmentId "env-123" -Version "10.0.47.5" -WaitForCompletion
        
        This will queue the update to D365 Finance and Operations version 10.0.47.5 for the specified environment.
        It will poll the operation status every 60 seconds until it succeeds or fails.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Version -EnvironmentId "env-123" -Latest | Invoke-PpacD365VersionUpdate
        
        This will get the latest available D365 Finance and Operations version for the specified environment.
        It will then queue the update to that version for the specified environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-PpacD365VersionUpdate {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $EnvironmentId,

        [parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [version] $Version,

        [switch] $WaitForCompletion
    )
    
    process {
        $envObj = Get-UnifiedEnvironment `
            -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        <#
            The apply endpoint expects the full application version (10.0.X.Y), so resolve
            the requested version against the available versions first.
        #>
        $colVersions = Get-PpacD365Version -EnvironmentId $envObj.PpacEnvId

        $deployVersion = $colVersions | `
            Where-Object Version -eq $Version.ToString() | `
            Select-Object -First 1

        if ($null -eq $deployVersion) {
            $tmpVersion = $Version.ToString().Substring(0, 7)
            $deployVersion = $colVersions | `
                Where-Object Platform -eq $tmpVersion | `
                Select-Object -First 1
        }

        if ($null -eq $deployVersion) {
            $messageString = "The specified version <c='em'>$Version</c> was not valid for the environment. Please verify the available versions using the <c='em'>Get-PpacD365Version</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "The specified version was not valid for the environment." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if (Test-PSFFunctionInterrupt) { return }

        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi

        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }

        $localUri = "https://api.powerplatform.com/dynamics/environments/{0}/finopsversions/{1}/apply?api-version=2024-10-01" `
            -f $envObj.PpacEnvId, $deployVersion.Version

        $resApply = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersPowerApi `
            -SkipHttpErrorCheck `
            -StatusCodeVariable 'statusApply' `
            -ResponseHeadersVariable 'headersApply' 4> $null

        if ($statusApply -eq 204) {
            Write-PSFMessage -Level Verbose -Message "Environment '$($envObj.PpacEnvName)' is already at or above version '$($deployVersion.Version)'. No update was queued."

            [PsCustomObject][ordered]@{
                EnvironmentId   = $envObj.PpacEnvId
                EnvironmentName = $envObj.PpacEnvName
                Version         = "$($deployVersion.Version)"
                OperationId     = $null
                ResourceId      = $null
                Status          = "NoUpdateRequired"
                PSTypeName      = "D365Bap.Tools.D365VersionUpdate"
            }
            return
        }

        if (-not ($statusApply -like "2**")) {
            $messageString = "Failed to queue D365 Finance and Operations update to version: <c='em'>$($deployVersion.Version)</c> for environment: <c='em'>$($envObj.PpacEnvName)</c>. HTTP status code: $statusApply."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because queuing the D365 version update failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $operationResult = [PsCustomObject][ordered]@{
            EnvironmentId   = $envObj.PpacEnvId
            EnvironmentName = $envObj.PpacEnvName
            Version         = "$($deployVersion.Version)"
            OperationId     = "$($resApply.operationId)"
            ResourceId      = "$($resApply.resourceId)"
            Status          = "Accepted"
            PSTypeName      = "D365Bap.Tools.D365VersionUpdate"
        }

        if (-not $WaitForCompletion) {
            $operationResult
            return
        }

        $pollUri = "https://api.powerplatform.com/environmentmanagement/environments/{0}/operations/{1}?api-version=2024-10-01" `
            -f $envObj.PpacEnvId, $resApply.operationId

        do {
            $secureTokenPoll = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
            $tokenPollValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPoll

            $headersPoll = @{
                "Authorization" = "Bearer $($tokenPollValue)"
            }

            Start-Sleep -Seconds 60

            $resOperation = Invoke-RestMethod -Method Get `
                -Uri $pollUri `
                -Headers $headersPoll 4> $null

            $operationStatus = "$($resOperation.status)"

            Write-PSFMessage -Level Verbose -Message "D365 version update operation '$($resApply.operationId)' status: $operationStatus."
        } while ($operationStatus -in @("Queued", "InProgress"))

        $operationResult.Status = $operationStatus
        $operationResult | Add-Member -MemberType NoteProperty -Name Operation -Value $resOperation -Force

        if ($operationStatus -in @("Failed", "ValidationFailed")) {
            $messageString = "D365 Finance and Operations update to version <c='em'>$($deployVersion.Version)</c> for environment <c='em'>$($envObj.PpacEnvName)</c> ended with status: $operationStatus."
            Write-PSFMessage -Level Important -Message $messageString
        }

        $operationResult
    }
    
    end {
        
    }
}
