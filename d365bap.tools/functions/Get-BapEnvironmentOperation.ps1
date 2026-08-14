
<#
    .SYNOPSIS
        Get environment life cycle operation info
        
    .DESCRIPTION
        Enables the user to query and validate all life cycle operations for a specific environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER LatestOnly
        Instructs the cmdlet to return only the latest operation.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentOperation -EnvironmentId "env-123"
        
        This will retrieve all environment operations for the specified environment id.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentOperation -EnvironmentId "env-123" -LatestOnly
        
        This will retrieve only the latest environment operation for the specified environment id.
        It is based on the created date.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentOperation -EnvironmentId "env-123" -AsExcelOutput
        
        This will retrieve all environment operations for the specified environment id.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentOperation {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [switch] $LatestOnly,

        [switch] $AsExcelOutput
    )

    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-BapEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        $localUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/lifecycleOperations?api-version=2024-05-01&`$filter=environment eq '$($envObj.EnvId)'"
        
        $colOps = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersBapApi | Select-Object -ExpandProperty Value

        if ($LatestOnly) {
            $colOps = $colOps | Select-Object -First 1
        }

        $resCol = @(
            $colOps | Select-PSFObject -TypeName "D365Bap.Tools.BapEnvironmentOperation" `
                -ExcludeProperty "Type", "requestedBy" `
                -Property "typeDisplayName as Type",
            "state.id as Status",
            "createdDateTime as StartedOn",
            "lastActionDateTime as LastAction",
            "stages[0].state.id as ValidateStatus",
            "stages[0].firstActionDateTime as ValidateStartedOn",
            "stages[0].lastActionDateTime as ValidateLastAction",
            "stages[1].state.id as PrepareStatus",
            "stages[1].firstActionDateTime as PrepareStartedOn",
            "stages[1].lastActionDateTime as PrepareLastAction",
            "stages[2].state.id as RunStatus",
            "stages[2].firstActionDateTime as RunStartedOn",
            "stages[2].lastActionDateTime as RunLastAction",
            "stages[3].state.id as FinalizeStatus",
            "stages[3].firstActionDateTime as FinalizeStartedOn",
            "stages[3].lastActionDateTime as FinalizeLastAction",
            "requestedBy.displayName as RequestedBy",
            "*"
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapEnvironmentOperation" `
                -WarningAction SilentlyContinue
            return
        }

        $resCol
    }
    
    end {
        
    }
}