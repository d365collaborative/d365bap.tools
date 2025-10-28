
<#
    .SYNOPSIS
        Gets UDE database JIT access information for a specified environment.
        
    .DESCRIPTION
        This function retrieves UDE database JIT access information for a specified environment.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .PARAMETER WhitelistIp
        Ip address to whitelist for JIT database access.
        
        Defaults to 127.0.0.1 - which will cause the function to determine the public IP address of the machine running the command.
        
    .PARAMETER Role
        The role to assign for JIT database access.
        
        Can be either "Reader" or "Writer".
        
        Defaults to "Reader".
        
    .PARAMETER Reason
        The reason for requesting JIT database access.
        
        Defaults to "Administrative access via d365bap.tools".

    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.

        Will include all properties, including those not shown by default in the console output.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "env-123"
        
        This will retrieve the JIT database access information for the specified environment ID.
        It will whitelist the public IP address of the machine running the command.
        It will assign the "Reader" role.
        It will use the default reason.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "env-123" -WhitelistIp "85.168.174.10"
        
        This will retrieve the JIT database access information for the specified environment ID.
        It will whitelist the specified IP address "85.168.174.10".
        It will assign the "Reader" role.
        It will use the default reason.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "env-123" -Role "Writer"
        
        This will retrieve the JIT database access information for the specified environment ID.
        It will whitelist the public IP address of the machine running the command.
        It will assign the "Writer" role.
        It will use the default reason.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "env-123" -Reason "Needed for data migration"
        
        This will retrieve the JIT database access information for the specified environment ID.
        It will whitelist the public IP address of the machine running the command.
        It will assign the "Reader" role.
        It will use the specified reason "Needed for data migration".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeDbJit {
    [CmdletBinding()]
    param (
        [Parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [string] $WhitelistIp = "127.0.0.1",

        [ValidateSet("Reader", "Writer")]
        [string] $Role = "Reader",

        [string] $Reason = "Administrative access via d365bap.tools",

        [switch] $AsExcelOutput
    )
    
    begin {
        $envObj = Get-UdeEnvironment -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UdeEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        if ($WhitelistIp -eq "127.0.0.1") {
            $WhitelistIp = (Invoke-RestMethod -Uri "https://icanhazip.com" -UseBasicParsing).Trim()
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        if ($WhitelistIp -eq "127.0.0.1") {
            $messageString = "Could not determine public IP address for JIT database access. Please specify the IP address using the <c='em'>-WhitelistIp</c> parameter."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because public IP address could not be determined."
            return
        }

        $baseUri = $envObj.PpacEnvUri + "/" #! Very important to have the trailing slash

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
            "Accept"        = "application/json"
            "Content-Type"  = "application/json; charset=utf-8"
        }

        $localUri = $baseUri + 'api/data/v9.2/msprov_getfinopssqljitaccessasync'

        $payload = @{
            "sqljitclientipaddress" = $WhitelistIp
            "sqljitreason"          = $Reason
            "sqljitrole"            = $Role
        } | ConvertTo-Json -Depth 3


        $resRequest = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headers `
            -Body $payload

        $resCol = @(
            $resRequest | Select-PSFObject -TypeName "D365Bap.Tools.UdeDatabaseJit" `
                -ExcludeProperty "@odata.context" `
                -Property "servername as Server",
            "databasename as Database",
            "sqljitusername as Username",
            "sqljitpassword as Password",
            "sqljitexpiration as Expiration",
            "sqljitrole as Role",
            *
        )
        
        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-UdeDbJit"
            return
        }

        $resCol
    }

    end {
    }
}