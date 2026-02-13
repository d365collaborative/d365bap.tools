
<#
    .SYNOPSIS
        Get solutions from Power Platform environment.
        
    .DESCRIPTION
        Enables the user to query against the solutions from the Power Platform environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Name
        The name of the solution that you are looking for.
        
        The parameter supports wildcards, but will resolve them into a strategy that matches best practice from Microsoft documentation.
        
        It means that you can only have a single search phrase. E.g.
        * -Name "*Retail"
        * -Name "Retail*"
        * -Name "*Retail*"
        
        It will search in both friendly name, unique name and id of the solution.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state.
        
    .EXAMPLE
        PS C:\> Get-PpeSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all solutions from the environment.
        
    .EXAMPLE
        PS C:\> Get-PpeSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "*invoice*"
        
        This will fetch solutions with "invoice" in their name from the environment.
        
    .EXAMPLE
        PS C:\> Get-PpeSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will fetch all solutions from the environment.
        It will then output the results directly into an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpeSolution {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }
        
        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
     
        [System.Collections.Generic.List[System.String]]$filters = @()

        $localUri = $baseUri + "/api/data/v9.2/solutions?`$expand=publisherid(`$select=friendlyname,uniquename)"
     
        $filters.Add("isvisible eq true")
        
        if ($filters.count -gt 0) {
            # We need to handle multiple filters
            $localUri += '&$filter='
            $localUri += $($filters.ToArray() -join " or ")
        }

        $colSolutionsRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $colSolutions = $colSolutionsRaw | Where-Object { ($_.friendlyname -like $Name -or $_.friendlyname -eq $Name) `
                -or ($_.uniquename -like $Name -or $_.uniquename -eq $Name) `
                -or ($_.solutionId -like $Name -or $_.solutionId -eq $Name)
        } | Sort-Object -Property friendlyname

        $resCol = @(
            $colSolutions | Select-PSFObject -TypeName "D365Bap.Tools.PpeSolution" `
                -ExcludeProperty solutionId, isvisible, version `
                -Property "solutionId as PpeSolutionId",
            "friendlyname as Name",
            "uniquename as SystemName",
            "version as Version",
            @{ Name = "PublisherName"; Expression = { $_.publisherid.friendlyname } },
            @{ Name = "Publisher"; Expression = { $_.publisherid.uniquename } },
            "isvisible as IsVisible",
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpeSolution"
            return
        }

        $resCol
    }
    
    end {
        
    }
}