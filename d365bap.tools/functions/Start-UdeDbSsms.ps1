
<#
    .SYNOPSIS
        Starts SQL Server Management Studio (SSMS) with the specified JIT access credentials.
        
    .DESCRIPTION
        This function starts SQL Server Management Studio (SSMS) and connects to the specified database using the JIT access credentials stored in the local cache.
        
    .PARAMETER Id
        The unique identifier for the JIT access credentials.
        
    .PARAMETER Version
        The version of SSMS to use (20 or 21).
        
    .EXAMPLE
        PS C:\> Start-UdeDbSsms -Id "demo"
        
        This will start SSMS version 20 and connect to the database using the JIT access credentials for the ID "demo".
        
    .EXAMPLE
        PS C:\> Start-UdeDbSsms -Id "demo" -Version 21
        
        This will start SSMS version 21 and connect to the database using the JIT access credentials for the ID "demo".
        
    .NOTES
        You need to have persisted JIT credentials using Set-UdeDbJitCache before using this function.
        
        Author: Mötz Jensen (@Splaxi)
#>
function Start-UdeDbSsms {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Id,

        [ValidateSet(20, 21)]
        [int] $Version = 20
    )

    process {
        $udeCreds = Get-UdeDbJitCache -Id $Id

        if ($null -eq $udeCreds) {
            Write-PSFMessage -Level Host -Message "No credential found for Id '$Id'. Please check the Id and try again."
            Stop-PSFFunction -Message "Stopping because no matching credential was found."

            return
        }

        # Hack to get the SSMS executable path from the registry
        $ssmsInstalled = Get-ChildItem `
            -Path Registry::HKEY_CLASSES_ROOT\ssms.*\shell\Open\Command | `
            Select-Object -ExpandProperty PsPath | `
            ForEach-Object { (Get-ItemProperty -Path $_)."(Default)" } | `
            Select-String -Pattern '^[\"]?(.*ssms\.exe)["]?\s*"%1"' | `
            ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -Unique

        $executablePath = $ssmsInstalled | `
            Where-Object { $_ -match "Microsoft SQL Server Management Studio $($Version)\b" } | `
            Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($executablePath)) {
            Write-PSFMessage -Level Host -Message "Could not find a valid SSMS executable for version <c='em'>$Version</c>. Please ensure the version is installed or try a different version."
            Stop-PSFFunction -Message "Stopping because SSMS executable was not found."
            return
        }

        & $executablePath -S $($udeCreds.Server) -d $($udeCreds.Database) -U $($udeCreds.Username)
    }
}