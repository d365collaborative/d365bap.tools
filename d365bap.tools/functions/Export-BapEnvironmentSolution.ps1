
<#
    .SYNOPSIS
        Export PowerPlatform / Dataverse Solution from the environment
        
    .DESCRIPTION
        Enables the user to export solutions, on a given environment
        
        The cmdlet downloads the solution, extracts it and removes unnecessary  files
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER SolutionId
        The id of the solution that you want to work against
        
        This can be obtained from the Get-BapEnvironmentSolution cmdlet
        
    .PARAMETER Path
        Path to the location that you want the files to be exported to
        
    .EXAMPLE
        PS C:\> Export-BapEnvironmentSolution -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -SolutionId 3ac10775-0808-42e0-bd23-83b6c714972f -Path "C:\Temp\"
        
        This will export the solution from the environment.
        It will extract the files into the "C:\Temp\" location.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Export-BapEnvironmentSolution {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (mandatory = $true)]
        [string] $SolutionId,

        [parameter (mandatory = $true)]
        [string] $Path
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

        $solObj = Get-BapEnvironmentSolution -EnvironmentId $EnvironmentId -SolutionId $SolutionId | Select-Object -First 1

        if ($null -eq $solObj) {
            $messageString = "The supplied SolutionId: <c='em'>$SolutionId</c> didn't return any matching solution from the environment. Please verify that the SolutionId is correct - try running the <c='em'>Get-BapEnvironmentSolution</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because solution was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $tmp = pac org list --filter $EnvironmentId

        Write-PSFMessage -Level Host -Message "<c='em'>$($tmp[0])</c>"
        
        $found = $false
        foreach ($line in $tmp) {
            $found = $line -like "*$EnvironmentId*"

            if ($found) {
                break
            }
        }

        if (-not $found) {
            $messageString = "It seems that the current pac cli session isn't connected to the correct tenant. Please run the <c='em'>pac auth create --name 'ChangeThis'</c> and make sure to use credentials that have enough privileges."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because pac cli session is NOT connected to the correct tenant." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        # pac cli is connected to the correct tenant
        $pathDownload = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), 'zip')

        $tmp = pac solution export --name $solObj.SystemName --environment $EnvironmentId --path $pathDownload --overwrite

        if (-not (($tmp | Select-Object -Last 1) -eq "Solution export succeeded.")) {
            $messageString = "It seems that export of the solution encountered some kind of error. Please run the cmdlet <c='em'>again in a few minutes</c>."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because export failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        Expand-Archive -Path $pathDownload -DestinationPath $Path -Force

        # Give the file system time to persis the extracted files.
        Start-Sleep -Seconds 2

        Remove-Item -LiteralPath $(Join-Path -Path $Path -ChildPath "[Content_Types].xml") -ErrorAction SilentlyContinue -Force
    }
    
    end {
        
    }
}