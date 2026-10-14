<#
    .SYNOPSIS
        Remove a unified environment from a Power Platform tenant.

    .DESCRIPTION
        Removes a unified environment (UDE/USE) and everything inside it from the tenant.

        Nothing is removed unless the -Force switch is supplied.
        Without -Force the cmdlet lists the environment and the resources that would be removed together with it.

        Only unified environments are supported. Other environment types must be removed from the Power Platform Admin Center (PPAC).

        A removed environment can be recovered from the Power Platform Admin Center (PPAC) for a limited period, normally seven days.

    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.

        Can be either the environment name or the environment GUID (PPAC). Supports wildcards, but has to match a single environment.

    .PARAMETER Force
        Instructs the cmdlet to proceed with removing the environment.

        Nothing happens unless this parameter is supplied.

    .PARAMETER WaitForCompletion
        Instructs the cmdlet to wait until the environment has been removed from the tenant.

    .PARAMETER DeletionTimeoutMinutes
        Maximum number of minutes to wait for the environment to be removed.

        Prevents endless waiting when the removal is stuck or has failed.

        Is only used together with the -WaitForCompletion parameter.

        Defaults to 60 minutes. Valid range is 1 to 720 minutes.

    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "env-123"

        This will show the environment and the resources that would be removed for the specified environment id.
        It will NOT remove the environment yet, allowing you to review it before deciding to remove it.

    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "env-123" -Force

        This will remove the specified environment without further confirmation.

    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "env-123" -Force -WaitForCompletion

        This will remove the specified environment without further confirmation.
        It will wait until the environment has been removed from the tenant.

    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironment -EnvironmentId "env-123" -Force -WaitForCompletion -DeletionTimeoutMinutes 120

        This will remove the specified environment without further confirmation.
        It will wait up to 120 minutes for the environment to be removed from the tenant.

    .NOTES
        Author: Stefan Vestergaard
#>
function Remove-UnifiedEnvironment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [switch] $Force,

        [switch] $WaitForCompletion,

        [ValidateRange(1, 720)]
        [int] $DeletionTimeoutMinutes = 60
    )

    begin {
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colEnvs = @(Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails)

        if ($colEnvs.Count -lt 1) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if ($colEnvs.Count -gt 1) {
            Write-PSFMessage -Level Important -Message "The supplied EnvironmentId <c='em'>$EnvironmentId</c> matched the following environments:"
            $colEnvs | ForEach-Object { Write-PSFMessage -Level Important -Message " - <c='em'>$($_.PpacEnvName)</c> ($($_.PpacEnvId))" }

            $messageString = "The EnvironmentId has to match a single environment. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the id matched multiple environments." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $envObj = $colEnvs[0]

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }

        $baseUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($envObj.PpacEnvId)"

        $validateParams = @{
            Method             = 'Post'
            Uri                = "$baseUri/validateDelete`?api-version=2021-04-01"
            Headers            = $headersBapApi
            SkipHttpErrorCheck = $true
            StatusCodeVariable = 'statusValidate'
        }

        $resValidate = Invoke-RestMethod @validateParams 4>$null

        if (-not ($statusValidate -like "2**")) {
            Write-PSFMessage -Level Important -Message "Unable to validate the removal of environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). HTTP status code: $statusValidate. The removal will be requested without validation."
            $resValidate = $null
        }
        elseif ($false -eq $resValidate.canInitiateDelete) {
            $reasonString = @($resValidate.errorMessage, $resValidate.errorCode, "No reason was given by the API.") | `
                Where-Object { -not [System.String]::IsNullOrWhiteSpace($_) } | `
                Select-Object -First 1

            $messageString = "The environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) is not allowed to be removed. Reason: <c='em'>$reasonString</c>"

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the environment is not allowed to be removed." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if (-not $Force) {
            Write-PSFMessage -Level Important -Message "The following environment would be removed:"
            Write-PSFMessage -Level Important -Message " - <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) - $($envObj.PpacEnvUri)"

            if ($null -eq $resValidate) {
                Write-PSFMessage -Level Important -Message "The resources that would be removed together with the environment could <c='em'>NOT</c> be listed."
            }
            else {
                $colResources = @($resValidate.resourcesToBeDeleted | Where-Object { $null -ne $_ })

                if ($colResources.Count -gt 0) {
                    Write-PSFMessage -Level Important -Message "The following resources would be removed together with the environment:"
                    $colResources | Group-Object -Property "type" | ForEach-Object { Write-PSFMessage -Level Important -Message " - <c='em'>$($_.Name)</c>: $($_.Count)" }
                }
                else {
                    Write-PSFMessage -Level Important -Message "The API didn't report any resources that would be removed together with the environment."
                }
            }

            $messageString = "This will remove the listed environment and everything inside it. If you are sure, please re-run the command with the <c='em'>-Force</c> parameter."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Force parameter wasn't supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $deleteParams = @{
            Method             = 'Delete'
            Uri                = "$baseUri`?api-version=2021-04-01"
            Headers            = $headersBapApi
            SkipHttpErrorCheck = $true
            StatusCodeVariable = 'statusDelete'
        }

        $resDelete = Invoke-RestMethod @deleteParams 4>$null

        if (-not ($statusDelete -like "2**")) {
            $messageString = "Failed to remove environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). HTTP status code: $statusDelete."

            $reasonString = @($resDelete.error.message, $resDelete.error.code) | `
                Where-Object { -not [System.String]::IsNullOrWhiteSpace($_) } | `
                Select-Object -First 1

            if (-not [System.String]::IsNullOrWhiteSpace($reasonString)) {
                $messageString += " Reason: <c='em'>$reasonString</c>"
            }

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because removing the environment failed." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Write-PSFMessage -Level Important -Message "Removal of environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)) has been requested."

        if (-not $WaitForCompletion) { return }

        Write-PSFMessage -Level Important -Message "Waiting up to $DeletionTimeoutMinutes minutes for environment <c='em'>$($envObj.PpacEnvName)</c> to be removed..."

        $deletionDeadline = (Get-Date).AddMinutes($DeletionTimeoutMinutes)

        do {
            $envObjCurrent = Get-BapEnvironment -EnvironmentId $envObj.PpacEnvId | `
                Select-Object -First 1

            $environmentRemoved = $null -eq $envObjCurrent

            if (-not $environmentRemoved) {
                if ((Get-Date) -ge $deletionDeadline) {
                    $messageString = "Environment <c='em'>$($envObj.PpacEnvName)</c> was not removed within $DeletionTimeoutMinutes minutes. Last known state was <c='em'>$($envObjCurrent.State)</c>. The removal may still complete - please check the Power Platform Admin Center (PPAC)."
                    Write-PSFMessage -Level Important -Message $messageString
                    Stop-PSFFunction -Message "Stopping because environment removal timed out." `
                        -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                    return
                }

                Write-PSFMessage -Level Verbose -Message "Waiting for environment <c='em'>$($envObj.PpacEnvName)</c> to be removed..."
                Start-Sleep -Seconds 20
            }
        } until ($environmentRemoved)

        Write-PSFMessage -Level Important -Message "Removed environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId))."
    }

    end {
    }
}
