
<#
    .SYNOPSIS
        Remove solutions from a Power Platform environment.
        
    .DESCRIPTION
        Removes unmanaged Dataverse solutions (solutions) from a specified environment.
        
        Solutions are matched by friendly name, unique name or id. Nothing is removed unless the -Force switch is supplied.
        Without -Force the cmdlet lists the solutions that would be removed.
        
        Managed solutions cannot be uninstalled with this cmdlet when they have managed dependencies - remove the dependent components first.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Name
        The name of the solution that you want to remove.
        
        Can be either the friendly name, unique name or id of the solution. Supports wildcard characters for flexible matching.
        
        Defaults to "*" - combine with -Force to remove every unmanaged solution, which is almost never what you want.
        
    .PARAMETER Force
        Instructs the function to proceed with removing the solutions.
        
        Nothing happens unless this parameter is supplied.
        
    .EXAMPLE
        PS C:\> Remove-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "contoso_tools"
        
        This will show the solution that would be removed for the specified environment id.
        It will NOT remove the solution yet, allowing you to review it before deciding to remove it.
        
    .EXAMPLE
        PS C:\> Remove-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "contoso_tools" -Force
        
        This will remove the specified solution for the specified environment id without further confirmation.
        
    .EXAMPLE
        PS C:\> Get-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "*contoso*" | Remove-PpeSolution -Force
        
        This will remove all solutions returned for the specified environment id without further confirmation.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Remove-PpeSolution {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [Alias("SystemName", "PpeSolutionId")]
        [string] $Name = "*",

        [switch] $Force
    )

    begin {
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

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

        $colSolutions = @(Get-PpeSolution `
                -EnvironmentId $envObj.PpacEnvId `
                -Name $Name)

        if ($colSolutions.Count -lt 1) {
            $messageString = "No solutions found for environment <c='em'>$EnvironmentId</c> matching Name <c='em'>$Name</c>. Please verify the filter and try again, or list available solutions using <c='em'>Get-PpeSolution</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no solutions were found based on the supplied filter." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if (-not $Force) {
            Write-PSFMessage -Level Important -Message "The following solutions would be removed:"
            $colSolutions | ForEach-Object { Write-PSFMessage -Level Important -Message " - <c='em'>$($_.Name)</c> ($($_.SystemName))" }

            $messageString = "This will remove the listed solutions. If you are sure, please re-run the command with the <c='em'>-Force</c> parameter."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Force parameter wasn't supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        [System.Collections.Generic.List[System.Object]] $arrFailed = @()

        foreach ($solutionObj in $colSolutions) {
            $deleteUri = $baseUri + "/api/data/v9.2/solutions($($solutionObj.PpeSolutionId))"

            Invoke-RestMethod -Method Delete `
                -Uri $deleteUri `
                -Headers $headersWebApi `
                -StatusCodeVariable statusDelete > $null 4> $null

            if (-not ($statusDelete -like "2*")) {
                Write-PSFMessage -Level Important -Message "Failed to remove solution <c='em'>$($solutionObj.Name)</c> ($($solutionObj.SystemName)). HTTP status code: $statusDelete."
                $arrFailed.Add($solutionObj)
            }
            else {
                Write-PSFMessage -Level Verbose -Message "Removed solution '$($solutionObj.Name)' ($($solutionObj.SystemName))."
            }
        }

        if ($arrFailed.Count -gt 0) {
            $messageString = "The following solutions <c='em'>failed to be removed</c>:"
            Write-PSFMessage -Level Important -Message $messageString
            $arrFailed.ToArray()

            if ($arrFailed.Count -eq $colSolutions.Count) {
                Stop-PSFFunction -Message "Stopping because all solution removals failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }
    }

    end {
    }
}
