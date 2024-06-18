
<#
    .SYNOPSIS
        Get Security Roles from environment
        
    .DESCRIPTION
        Get Security Roles from the Dataverse environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER Name
        Name of the Security Role that you want to work against
        
        Supports wildcard search
        
        Default value is "*" - which translates into all available Security Roles
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will list all Security Roles from the Dataverse environment.
        
        Sample output:
        Id                                   Name                           ModifiedOn
        --                                   ----                           ----------
        5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realti… 03/02/2023 10.11.13
        1cbf96a1-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realti… 03/02/2023 10.11.14
        d364ba1c-1bfb-eb11-94f0-0022482381ee Accounts Payable Admin         17/08/2023 07.06.15
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "Environment*"
        
        This will list all Security Roles, which matches the "Environment*" pattern, from the Dataverse environment.
        
        Sample output:
        Id                                   Name                           ModifiedOn
        --                                   ----                           ----------
        d58407f2-48d5-e711-a82c-000d3a37c848 Environment Maker              15/06/2024 21.12.56
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will list all Security Roles from the Dataverse environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        General notes
#>
function Get-BapEnvironmentSecurityRole {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvUri
        $tokenWebApi = Get-AzAccessToken -ResourceUrl $baseUri
        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApi.Token)"
        }

        $languages = @(Get-EnvironmentLanguage -BaseUri $baseUri)
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $resRoles = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/roles') -Headers $headersWebApi

        $resCol = @(
            foreach ($roleObj in  $($resRoles.value | Sort-Object -Property name)) {
                if (-not ($roleObj.Name -like $Name)) { continue }
                
                $roleObj | Select-PSFObject -TypeName "D365Bap.Tools.Role" -ExcludeProperty "@odata.etag" -Property "roleid as Id", *
            }
        )

        if (-not $IncludeAppIds) {
            $resCol = $resCol | Where-Object applicationid -eq $null
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }
    
    end {
        
    }
}