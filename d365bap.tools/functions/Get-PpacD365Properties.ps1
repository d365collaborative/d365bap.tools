
<#
    .SYNOPSIS
        Get Finance and Operations properties for the environment.
        
    .DESCRIPTION
        Retrieves Finance and Operations environment properties from the Power Platform API (PPAC).
        
        Wraps GET /dynamics/environments/{environmentId}/finopsproperties (api-version 2024-10-01) and returns details such as deployment type, demo dataset, and AOS counts.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Properties -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will fetch the Finance and Operations properties for the environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Properties -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" | Format-List
        
        This will fetch the Finance and Operations properties for the environment.
        It will output all details in list view.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Properties -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
        
        This will fetch the Finance and Operations properties for the environment.
        It will output the results directly into an Excel file, that will automatically open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacD365Properties {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [switch] $AsExcelOutput
    )
    
    begin {
        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
        
        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $localUri = "https://api.powerplatform.com/dynamics/environments/$($envObj.PpacEnvId)/finopsproperties?api-version=2024-10-01"

        try {
            $propsRaw = Invoke-RestMethod `
                -Method Get `
                -Uri $localUri `
                -Headers $headersPowerApi 4> $null
        }
        catch {
            $statusCode = 0
            try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch { $statusCode = 0 }

            if ($statusCode -eq 404) {
                $messageString = "No Finance and Operations properties found for environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). The environment is most likely not Finance and Operations enabled."
                Write-PSFMessage -Level Warning -Message $messageString
                return
            }

            $messageString = "Failed retrieving Finance and Operations properties for environment <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId))."
            Write-PSFMessage -Level Warning -Message $messageString -ErrorRecord $_
            Stop-PSFFunction -Message "Stopping because the FinOps properties request failed." -ErrorRecord $_
            return
        }

        if ($null -eq $propsRaw) { return }

        $resCol = @(
            $propsRaw | Select-PSFObject -TypeName "D365Bap.Tools.PpacD365Properties" `
                -ExcludeProperty "appId", "deploymentType", "demoDataset", "lastObservedAOSCount", "lastObservedBatchAOSCount", "maxAOSCount", "maxBatchAOSCount" `
                -Property @{Name = "PpacEnvId"; Expression = { $envObj.PpacEnvId } },
            @{Name = "PpacEnvName"; Expression = { $envObj.PpacEnvName } },
            "appId as AppId",
            "deploymentType as DeploymentType",
            "demoDataset as DemoDataset",
            "lastObservedAOSCount as LastObservedAOSCount",
            "lastObservedBatchAOSCount as LastObservedBatchAOSCount",
            "maxAOSCount as MaxAOSCount",
            "maxBatchAOSCount as MaxBatchAOSCount",
            "*"
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacD365Properties" `
                -WarningAction SilentlyContinue
            return
        }

        $resCol
    }
    
    end {
        
    }
}
