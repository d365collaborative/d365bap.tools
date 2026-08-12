
<#
    .SYNOPSIS
        Get an OData access token for a Finance and Operations environment.
        
    .DESCRIPTION
        Acquires an Azure access token scoped to the Finance and Operations (FnO) OData resource of the specified environment, using the cached credentials in the local Azure PowerShell context.
        
        The token is returned in plain text. Handle the output accordingly.
        
    .PARAMETER EnvironmentId
        The ID of the environment to acquire the token for.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER AsBearerToken
        Output the token as a "Bearer" prefix string, ready to use in an Authorization header.
        
    .PARAMETER AsObject
        Output a typed PSCustomObject with Token and BearerToken properties.
        
    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv"
        
        This command acquires an OData access token for the environment "ContosoEnv" and returns the raw token string.
        
    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv" -AsBearerToken
        
        This command acquires an OData access token for the environment "ContosoEnv" and returns it as a bearer token string, ready to use directly in an Authorization header.
        
    .EXAMPLE
        PS C:\> $token = Get-FscmOdataToken -EnvironmentId "ContosoEnv" -AsObject
        PS C:\> Invoke-RestMethod -Uri $uri -Headers @{ Authorization = $token.BearerToken }
        
        This command acquires an OData access token for the environment "ContosoEnv" and returns a typed object with both Token and BearerToken properties.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataToken {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([System.String], ParameterSetName = 'Default')]
    [OutputType([System.String], ParameterSetName = 'BearerToken')]
    [OutputType([System.Management.Automation.PSObject], ParameterSetName = 'Object')]
    param (
        [Parameter (Mandatory = $true, ParameterSetName = 'Default')]
        [Parameter (Mandatory = $true, ParameterSetName = 'BearerToken')]
        [Parameter (Mandatory = $true, ParameterSetName = 'Object')]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true, ParameterSetName = 'BearerToken')]
        [switch] $AsBearerToken,

        [Parameter (Mandatory = $true, ParameterSetName = 'Object')]
        [switch] $AsObject
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

        # Branch on the switch parameters so PSScriptAnalyzer sees them as used
        # (parameter sets alone do not count as usage for PSReviewUnusedParameter).
        if ($AsObject) {
            [PSCustomObject]@{ Token = $tokenValue } | `
                Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataToken" `
                -Property "Token",
            @{ Name = "BearerToken"; Expression = { "Bearer $($_.Token)" } }
        }
        elseif ($AsBearerToken) {
            "Bearer $tokenValue"
        }
        else {
            $tokenValue
        }
    }
    
    end {
        
    }
}