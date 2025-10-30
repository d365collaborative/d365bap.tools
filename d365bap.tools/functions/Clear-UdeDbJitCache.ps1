
<#
    .SYNOPSIS
        Clears the JIT cache for the UDE database.
        
    .DESCRIPTION
        This function clears the Just-In-Time (JIT) cache for the UDE database by removing expired credentials and resetting the cache configuration.
        
    .PARAMETER Force
        Instructs the function to clear all cached JIT credentials regardless of their expiration status.
        
    .EXAMPLE
        PS C:\> Clear-UdeDbJitCache
        
        This will clear all expired JIT database access credentials from the local cache.
        
    .EXAMPLE
        PS C:\> Clear-UdeDbJitCache -Force
        
        This will clear all JIT database access credentials from the local cache, regardless of their expiration status.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Clear-UdeDbJitCache {
    [CmdletBinding()]
    param (
        [switch] $Force
    )

    begin {
        if ($null -eq (Get-Module TUN.CredentialManager -ListAvailable)) {
            Write-PSFMessage -Level Host -Message "This cmdlet needs the <c='em'>TUN.CredentialManager</c> module. Please install it from the PowerShell Gallery with <c='em'>Install-Module -Name TUN.CredentialManager</c> and try again."
            Stop-PSFFunction -Message "Stopping because the TUN.CredentialManager module is not available."

            return
        }

        if (Test-PSFFunctionInterrupt) { return }

        Import-Module TUN.CredentialManager
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        if ($Force) {
            Set-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Value @{}
            Register-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Scope UserDefault
        
            $creds = (Get-StoredCredential -AsCredentialObject) | Where-Object TargetName -like '*SSMS*'
            foreach ($cred in $creds) {
                if ((-not $cred.TargetName -like "*spartan*")) { continue }
                if ((-not $cred.UserName -like "jit*")) { continue }

                Remove-StoredCredential -Target $cred.TargetName > $null
            }
            return
        }

        $now = Get-Date

        $credentials = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.ude.dbjit.cache")
        $creds = (Get-StoredCredential -AsCredentialObject) | Where-Object TargetName -like '*SSMS*'
        
        $colKeys = @()
        foreach ($credObj in $credentials.GetEnumerator()) {
            if ($credObj.Value.Expiration -lt $now) {

                $colRemove = @(
                    $creds | Where-Object UserName -eq $($credObj.Value.Username) | `
                        Select-Object -ExpandProperty TargetName
                )

                foreach ($target in $colRemove) {
                    Remove-StoredCredential -Target $target > $null
                }

                $colKeys += $credObj.Key
            }
        }

        foreach ($key in $colKeys) {
            $credentials.Remove($key) > $null
        }

        Set-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Value $credentials
        Register-PSFConfig -FullName "d365bap.tools.ude.dbjit.cache" -Scope UserDefault
    }
}