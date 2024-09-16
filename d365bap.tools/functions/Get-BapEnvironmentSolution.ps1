
<#
    .SYNOPSIS
        Get PowerPlatform / Dataverse Solution from the environment
        
    .DESCRIPTION
        Enables the user to list solutions and their meta data, on a given environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER SolutionId
        The id of the solution that you want to work against
        
        Leave blank to get all solutions
        
    .PARAMETER IncludeManaged
        Instruct the cmdlet to include all managed solution
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will query the specific environment.
        It will only list Unmanaged / NON-Managed solutions.
        
        Sample output:
        
        SolutionId                           Name                           IsManaged SystemName           Description
        ----------                           ----                           --------- ----------           -----------
        fd140aae-4df4-11dd-bd17-0019b9312238 Active Solution                False     Active               Placeholder solutioâ€¦
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged
        
        This will query the specific environment.
        It will list all solutions.
        
        Sample output:
        
        SolutionId                           Name                           IsManaged SystemName           Description
        ----------                           ----                           --------- ----------           -----------
        169edc7d-5f1e-4ee4-8b5c-135b3ba82ea3 Access Team                    True      AccessTeam           Access Team solution
        fd140aae-4df4-11dd-bd17-0019b9312238 Active Solution                False     Active               Placeholder solutioâ€¦
        458c32fb-4476-4431-97cb-49cfd069c31d Activities                     True      msdynce_Activities   Dynamics 365 workloâ€¦
        7553bb8a-fc5e-424c-9698-113958c28c98 Activities Patch               True      msdynce_ActivitiesPâ€¦ Patch for Dynamics â€¦
        3ac10775-0808-42e0-bd23-83b6c714972f ActivitiesInfra Solution Anchâ€¦ True      msft_ActivitiesInfrâ€¦ ActivitiesInfra Solâ€¦
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged
        
        This will query the specific environment.
        It will list all solutions, unmanaged / managed.
        
        Sample output:
        
        SolutionId                           Name                           IsManaged SystemName           Description
        ----------                           ----                           --------- ----------           -----------
        169edc7d-5f1e-4ee4-8b5c-135b3ba82ea3 Access Team                    True      AccessTeam           Access Team solution
        fd140aae-4df4-11dd-bd17-0019b9312238 Active Solution                False     Active               Placeholder solutioâ€¦
        458c32fb-4476-4431-97cb-49cfd069c31d Activities                     True      msdynce_Activities   Dynamics 365 workloâ€¦
        7553bb8a-fc5e-424c-9698-113958c28c98 Activities Patch               True      msdynce_ActivitiesPâ€¦ Patch for Dynamics â€¦
        3ac10775-0808-42e0-bd23-83b6c714972f ActivitiesInfra Solution Anchâ€¦ True      msft_ActivitiesInfrâ€¦ ActivitiesInfra Solâ€¦
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged -SolutionId 3ac10775-0808-42e0-bd23-83b6c714972f
        
        This will query the specific environment.
        It will list all solutions, unmanaged / managed.
        It will search for the 3ac10775-0808-42e0-bd23-83b6c714972f solution.
        
        Sample output:
        
        SolutionId                           Name                           IsManaged SystemName           Description
        ----------                           ----                           --------- ----------           -----------
        3ac10775-0808-42e0-bd23-83b6c714972f ActivitiesInfra Solution Anchâ€¦ True      msft_ActivitiesInfrâ€¦ ActivitiesInfra Solâ€¦
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -IncludeManaged -AsExcelOutput
        
        This will query the specific environment.
        It will list all solutions, unmanaged / managed.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentSolution {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [string] $SolutionId,

        [switch] $IncludeManaged,

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
        
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $localUri = $baseUri + '/api/data/v9.2/solutions'
        $search = '?$filter=ismanaged eq false'

        if (-not $IncludeManaged) {
            $localUri += $search
        }

        $resSolutions = Invoke-RestMethod -Method Get -Uri $localUri -Headers $headersWebApi

        $resCol = @(
            foreach ($solObj in  $($resSolutions.value | Sort-Object -Property friendlyname)) {
                if ((-not [System.String]::IsNullOrEmpty($SolutionId)) -and $solObj.SolutionId -ne $SolutionId) { continue }
                
                $solObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacSolution" -Property "uniquename as SystemName",
                "friendlyname as Name",
                *
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }
    
    end {
        
    }
}