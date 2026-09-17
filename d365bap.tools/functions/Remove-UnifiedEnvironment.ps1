
<#
    .SYNOPSIS
        Remove a Unified Environment.
        
    .DESCRIPTION
        Deletes a Unified Environment (UDE/USE) - and everything that lives inside it - from the tenant.
        
        Only Unified Environments are supported. Environments that are linked to LCS (LcsDevbox, LcsSandbox, LcsProduction), or plain Dataverse environments, will be rejected - please delete those from the Power Platform Admin Center (PPAC) instead.
        
        The cmdlet asks the Power Platform Admin Center (PPAC) API to validate that the environment is allowed to be deleted.
        
        Nothing is deleted unless the -Force parameter is supplied, which makes it possible to review the impact before committing to the deletion.
        
        Please note that this is a destructive operation. Depending on the type of the environment, it might be recoverable for a limited period of time - see the "Recover environment" capabilities in the Power Platform Admin Center (PPAC).
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.

        Can be either the environment name or the environment GUID (PPAC). The LCS environment ID is NOT supported.

        It has to match a single environment only - the cmdlet will stop if the supplied value matches multiple environments.

    .PARAMETER Force
        Instructs the cmdlet to proceed with the deletion of the environment.

        Nothing is deleted unless this parameter is supplied. Without it, the cmdlet returns the environment details (from Get-UnifiedEnvironment) so you can review it before deleting.

    .PARAMETER WaitForCompletion
        Instructs the cmdlet to wait until the environment is gone from the tenant.
        
    .PARAMETER DeletionTimeoutMinutes
        Maximum number of minutes to wait for the environment to be deleted.
        
        Prevents endless waiting when the deletion is stuck or has failed.
        
        Is only used together with the -WaitForCompletion parameter.
        
        Default value is 60 minutes.
        
    .PARAMETER PollIntervalSeconds
        Number of seconds to wait between each check of the deletion status.
        
        Is only used together with the -WaitForCompletion parameter.
        
        Default value is 20 seconds.
        
    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "ContosoEnv"
        
        This will return the details for the Unified Environment "ContosoEnv".
        It will NOT delete anything, allowing you to review the environment before deciding to delete it.
        
    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "ContosoEnv" -Force
        
        This will delete the Unified Environment "ContosoEnv", and all the resources that lives inside it.
        It will return as soon as the deletion has been requested.
        
    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "ContosoEnv" -Force -WaitForCompletion
        
        This will delete the Unified Environment "ContosoEnv", and all the resources that lives inside it.
        It will wait until the environment is gone from the tenant.
        
    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "ContosoEnv" -Force -WaitForCompletion -DeletionTimeoutMinutes 120 -PollIntervalSeconds 60
        
        This will delete the Unified Environment "ContosoEnv", and all the resources that lives inside it.
        It will wait until the environment is gone from the tenant, checking the status every 60 seconds.
        It will stop waiting after 120 minutes.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -EnvironmentId "ContosoEnv" | Remove-UnifiedEnvironment -Force
        
        This will get the details for the Unified Environment "ContosoEnv".
        It will pipe the details into the Remove-UnifiedEnvironment cmdlet, which will delete the environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        Author: Stefan Vestergaard
#>
function Remove-UnifiedEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [switch] $Force,

        [switch] $WaitForCompletion,

        [ValidateRange(1, 720)]
        [int] $DeletionTimeoutMinutes = 60,

        [ValidateRange(5, 300)]
        [int] $PollIntervalSeconds = 20
    )
    
    begin {
        function Get-FirstValue {
            param (
                [object[]] $Value
            )

            $Value | Where-Object { -not [System.String]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
        }
    }
    
    process {
        $colEnvs = @(Get-UnifiedEnvironment `
                -EnvironmentId $EnvironmentId `
                -SkipVersionDetails)

        if ($colEnvs.Count -lt 1) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -OverrideExceptionMessage
            return
        }

        if ($colEnvs.Count -gt 1) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> matched <c='em'>$($colEnvs.Count)</c> environments. Deleting an environment is a destructive operation, so the EnvironmentId has to match a single environment only. Please be more specific - supply the environment id (GUID) or the exact name of one of the following environments:"
            Write-PSFMessage -Level Important -Message $messageString
            $colEnvs
            Stop-PSFFunction -Message "Stopping because the id matched multiple environments." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -OverrideExceptionMessage
            return
        }

        $envObj = $colEnvs[0]

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }

        $baseUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($envObj.PpacEnvId)"

        $localUri = "$baseUri/validateDelete`?api-version=2021-04-01"

        $resValidate = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersBapApi `
            -SkipHttpErrorCheck `
            -StatusCodeVariable 'statusValidate' 4> $null

        if (-not ($statusValidate -like "2**")) {
            Write-PSFMessage -Level Important -Message "Unable to validate whether the environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) can be deleted - HTTP status code: <c='em'>$statusValidate</c>. Continuing without the validation details."
        }
        elseif ($false -eq $resValidate.canInitiateDelete) {
            $reasonString = Get-FirstValue $resValidate.errorMessage, $resValidate.errorCode, "No reason was supplied by the API."

            $messageString = "The environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) is not allowed to be deleted. Reason: <c='em'>$reasonString</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the environment is not allowed to be deleted." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -OverrideExceptionMessage
            return
        }

        if (-not $Force) {
            Write-PSFMessage -Level Important -Message "Nothing was deleted. Re-run the command with the <c='em'>-Force</c> parameter to delete the environment."
            $envObj
            return
        }

        $localUri = "$baseUri`?api-version=2021-04-01"

        $resDelete = Invoke-RestMethod -Method Delete `
            -Uri $localUri `
            -Headers $headersBapApi `
            -SkipHttpErrorCheck `
            -StatusCodeVariable 'statusDelete' `
            -ResponseHeadersVariable 'headersDelete' 4> $null

        if (-not ($statusDelete -like "2**")) {
            $detailString = Get-FirstValue $resDelete.error.message, $resDelete.error.code, $resDelete.message

            $messageString = "Failed to delete the environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) - HTTP status code: <c='em'>$statusDelete</c>."
            $messageString += if ($detailString) { " Reason: <c='em'>$detailString</c>" } else { " Please investigate the issue - the Power Platform Admin Center (PPAC) might hold more details." }

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because deleting the environment failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -OverrideExceptionMessage
            return
        }

        $operationUri = if ($headersDelete) {
            Get-FirstValue $headersDelete.'Operation-Location', $headersDelete.'Azure-AsyncOperation', $headersDelete.Location
        }

        Write-PSFMessage -Level Verbose -Message "Deletion of the environment '$($envObj.PpacEnvName)' ($($envObj.PpacEnvId)) has been requested."

        if ($operationUri) {
            Write-PSFMessage -Level Verbose -Message "The deletion is tracked by the operation: '$operationUri'."
        }

        if (-not $WaitForCompletion) { return }

        $deletionStarted = Get-Date
        $deletionDeadline = $deletionStarted.AddMinutes($DeletionTimeoutMinutes)
        $deletionSeconds = $DeletionTimeoutMinutes * 60
        $progressActivity = "Deleting the environment '$($envObj.PpacEnvName)'"
        $environmentDeleted = $false
        $statusString = "Deletion requested"

        try {
            do {
                if ($operationUri) {
                    $resOperation = Invoke-RestMethod -Method Get `
                        -Uri $operationUri `
                        -Headers $headersBapApi `
                        -SkipHttpErrorCheck `
                        -StatusCodeVariable 'statusOperation' 4> $null

                    if ($statusOperation -eq 404) {
                        $operationUri = ""
                    }
                    elseif ($statusOperation -like "2**") {
                        $operationState = Get-FirstValue $resOperation.status, $resOperation.state.id, $resOperation.properties.provisioningState, $resOperation.provisioningState

                        if ($operationState) {
                            $statusString = $operationState

                            if ($operationState -in @("Succeeded", "Completed", "Deleted")) {
                                $environmentDeleted = $true
                            }
                            elseif ($operationState -in @("Failed", "Canceled", "Cancelled")) {
                                $detailString = Get-FirstValue $resOperation.error.message, $resOperation.error.code, $resOperation.message

                                $messageString = "The deletion of the environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) failed - the operation reported the state: <c='em'>$statusString</c>."
                                $messageString += if ($detailString) { " Reason: <c='em'>$detailString</c>" } else { " Please investigate the issue - the Power Platform Admin Center (PPAC) might hold more details." }

                                Write-PSFMessage -Level Important -Message $messageString
                                Stop-PSFFunction -Message "Stopping because the deletion of the environment failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -OverrideExceptionMessage
                                return
                            }
                        }
                    }
                }

                if (-not $environmentDeleted) {
                    $envObjCurrent = Get-BapEnvironment -EnvironmentId $envObj.PpacEnvId | Select-Object -First 1
                    $environmentDeleted = $null -eq $envObjCurrent

                    if ((-not $environmentDeleted) -and (-not [System.String]::IsNullOrWhiteSpace($envObjCurrent.State))) {
                        $statusString = $envObjCurrent.State
                    }
                }

                if ($environmentDeleted) { continue }

                if ((Get-Date) -ge $deletionDeadline) {
                    $messageString = "The environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) was not deleted within $DeletionTimeoutMinutes minutes. Last known state was '$statusString'."
                    Write-PSFMessage -Level Important -Message $messageString
                    Stop-PSFFunction -Message "Stopping because the deletion of the environment timed out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -OverrideExceptionMessage
                    return
                }

                $secondsElapsed = ((Get-Date) - $deletionStarted).TotalSeconds

                Write-Progress -Activity $progressActivity `
                    -Status "State: $statusString - waiting for the environment to be deleted" `
                    -PercentComplete ([int][System.Math]::Min(99, ($secondsElapsed / $deletionSeconds) * 100)) `
                    -SecondsRemaining ([int][System.Math]::Max(0, $deletionSeconds - $secondsElapsed))

                Write-PSFMessage -Level Verbose -Message "Waiting for the environment '$($envObj.PpacEnvName)' to be deleted - current state: '$statusString' ..."
                Start-Sleep -Seconds $PollIntervalSeconds
            } until ($environmentDeleted)
        }
        finally {
            Write-Progress -Activity $progressActivity -Completed
        }

        Write-PSFMessage -Level Verbose -Message "The environment '$($envObj.PpacEnvName)' ($($envObj.PpacEnvId)) has been deleted."
    }
    
    end {
        
    }
}