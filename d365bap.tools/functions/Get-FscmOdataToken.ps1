
<#
    .SYNOPSIS
        Get an OData access token for a Finance and Operations environment.
        
    .DESCRIPTION
        Acquires an Azure access token scoped to the Finance and Operations (FnO) OData resource of the specified environment, using the cached credentials in the local Azure PowerShell context.
        
        Returns both the raw token and a ready-to-use bearer token string, so the token can be inspected or reused in custom REST calls against the FnO endpoints.
        
        The token is returned in plain text. Handle the output accordingly.
        
    .PARAMETER EnvironmentId
        The ID of the environment to acquire the token for.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv"
        
        This command acquires an OData access token for the environment "ContosoEnv" and returns an object with the raw Token and a ready-to-use BearerToken.
        
    .EXAMPLE
        PS C:\> $token = Get-FscmOdataToken -EnvironmentId "ContosoEnv"
        PS C:\> Invoke-RestMethod -Uri $uri -Headers @{ Authorization = $token.BearerToken }
        
        This command acquires an OData access token for the environment "ContosoEnv" and uses the BearerToken property directly in the Authorization header of a custom REST call.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataToken {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        [PSCustomObject]@{ Token = $tokenValue } | `
            Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataToken" `
            -Property "Token",
        @{ Name = "BearerToken"; Expression = { "Bearer $($_.Token)" } }
    }
    
    end {
        
    }
}