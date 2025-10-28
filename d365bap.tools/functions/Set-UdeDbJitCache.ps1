
<#
    .SYNOPSIS
        Sets UDE database JIT access credentials in the local cache.
        
    .DESCRIPTION
        This function sets UDE database JIT access credentials in the local cache for later retrieval.
        
        Handles storing the credentials securely using the TUN.CredentialManager module.
        Made to have SSMS able to retrieve the password when connecting.
        
    .PARAMETER Id
        The unique identifier for the JIT access credentials.
        
    .PARAMETER Server
        The SQL Server instance name.
        
    .PARAMETER Database
        The database name.
        
    .PARAMETER Username
        The username for the JIT access credentials.
        
    .PARAMETER Password
        The password for the JIT access credentials.
        
    .PARAMETER Expiration
        The expiration date and time for the JIT access credentials.
        
    .PARAMETER Role
        The role assigned for JIT database access. Can be either "Reader" or "Writer".
        
        Defaults to "Reader".
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .EXAMPLE
        PS C:\> Set-UdeDbJitCache -Id "demo" -Server "myserver.database.windows.net" -Database "mydatabase" -Username "myuser" -Password "mypassword"
        
        This will set the JIT database access credentials in the local cache for the specified ID.
        It will store the server, database, username, and password securely using the TUN.CredentialManager module.
        
    .EXAMPLE
        PS C:\> Get-UdeDbJit -EnvironmentId "env-123" | Set-UdeDbJitCache -Id "demo" -EnvironmentId "env-123"
        
        This will retrieve the JIT database access information for the specified environment ID using Get-UdeDbJit.
        It will then set the JIT database access credentials in the local cache for the ID "demo".
        It will store the server, database, username, and password securely using the TUN.CredentialManager module.
        It will store the expiration and role as provided by Get-UdeDbJit.
        It will also associate the environment details with the cached credentials.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-UdeDbJitCache {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Server,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Database,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Username,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Password,

        [datetime] $Expiration = (Get-Date).AddHours(8),

        [ValidateSet("Reader", "Writer")]
        [string] $Role = "Reader",

        [string] $EnvironmentId
    )

    begin {
        if ($null -eq (Get-Module TUN.CredentialManager -ListAvailable)) {
            Write-PSFMessage -Level Host -Message "This cmdlet needs the <c='em'>TUN.CredentialManager</c> module. Please install it from the PowerShell Gallery with <c='em'>Install-Module -Name TUN.CredentialManager</c> and try again."
            Stop-PSFFunction -Message "Stopping because the TUN.CredentialManager module is not available."

            return
        }

        if (Test-PSFFunctionInterrupt) { return }

        Import-Module TUN.CredentialManager

        if ($null -ne $EnvironmentId) {
            $envObj = Get-UdeEnvironment -EnvironmentId $EnvironmentId `
                -SkipVersionDetails | Select-Object -First 1
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $SqlServerGUID = "8c91a03d-f9b4-46c0-a305-b5dcc79ff907"

        $details = [PSCustomObject][ordered]@{
            Id          = $Id
            Server      = $($Server)
            Database    = $($Database)
            Username    = $($Username)
            Expiration  = $($Expiration.ToString("s"))
            Role        = $($Role)
            PpacEnvId   = ""
            PpacEnvName = ""
        }

        if ($null -ne $envObj) {
            $details.PpacEnvId = $envObj.PpacEnvId
            $details.PpacEnvName = $envObj.PpacEnvName
        }

        # Setting up the SQL Server Management Studio (SSMS) Credential for version 20 - 21
        20, 21 | ForEach-Object {
            New-StoredCredential `
                -UserName $Username `
                -Password $Password `
                -Persist LocalMachine `
                -Target "Microsoft:SSMS:$($_):$($Server):$($Username):$($SqlServerGUID):1" > $null
        }

        $credentials = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.ude.dbjit.cache")
        $credentials."$Id" = $details

        Set-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Value $credentials
        Register-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Scope UserDefault

        # Get-D365UdeDatabaseCredential -Id $Id
    }
}