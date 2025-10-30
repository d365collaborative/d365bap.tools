
<#
    .SYNOPSIS
        Sets the UDE environment in the current PowerShell session.
        
    .DESCRIPTION
        This function sets the specified UDE environment in the current PowerShell session by updating the default parameter values for relevant cmdlets.
        
    .PARAMETER EnvironmentId
        The ID of the environment that you want to work against.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .EXAMPLE
        PS C:\> Set-UdeEnvironmentInSession -EnvironmentId "env-123"
        
        This will set the specified environment ID in the current PowerShell session.
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironment -EnvironmentId "env-123" | Set-UdeEnvironmentInSession
        
        This will set the environment ID from the piped UDE environment object in the current PowerShell session.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-UdeEnvironmentInSession {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId
    )

    begin {}

    process {
        $envObj = Get-UdeEnvironment -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id '<c='em'>$EnvironmentId</c>'. Please verify the Id and try again, or list available environments using <c='em'>Get-UdeEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # (Get-Command -Module d365bap.tools) | Where-Object { $_.Parameters.Keys -contains 'EnvironmentId' -and $_.Name -like "*-Ude*" } | Select-Object -Property Name

        $Global:PSDefaultParameterValues['Get-UdeDbJit:EnvironmentId'] = $envObj.PpacEnvId
        $Global:PSDefaultParameterValues['Get-UdeDeveloperFile:EnvironmentId'] = $envObj.PpacEnvId
    }

    end {}
}