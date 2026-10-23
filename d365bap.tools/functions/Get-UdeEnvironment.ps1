
<#
    .SYNOPSIS
        Gets UDE environment details.
        
    .DESCRIPTION
        Retrieves details for a Unified Development Environment (UDE).
        
        Currently reports the details from Get-UnifiedEnvironment.
        
    .PARAMETER EnvironmentId
        The ID of the environment that you want to work against.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironment -EnvironmentId "env-123"
        
        This will retrieve the UDE environment details for the specified environment ID.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeEnvironment {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId
    )

    begin {
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        Get-UnifiedEnvironment -EnvironmentId $EnvironmentId
    }

    end {
    }
}
