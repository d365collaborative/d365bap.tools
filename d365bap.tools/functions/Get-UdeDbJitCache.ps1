<#
.SYNOPSIS
Retrieves UDE database JIT access credentials from the local cache.

.DESCRIPTION
This function retrieves UDE database JIT access credentials from the local cache.

.PARAMETER Id
The unique identifier for the JIT access credentials.

.PARAMETER ShowPassword
Instructs the function to include the password in the output.

.EXAMPLE
PS C:\> Get-UdeDbJitCache -Id "demo"

This will retrieve the JIT database access credentials for the ID "demo".

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeDbJitCache {
    [CmdletBinding()]
    param (
        [Alias("Name")]
        [string] $Id = "*",

        [switch] $ShowPassword
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

        $credentials = [hashtable](Get-PSFConfigValue -FullName "d365bap.tools.ude.dbjit.cache")

        $col = @(
            foreach ($key in $credentials.Keys) {
                if ($key -like $Id) {
                    $credentials[$key]
                }
            }
        )

        if ($ShowPassword) {
            $creds = (Get-StoredCredential -AsCredentialObject) | Where-Object TargetName -like '*SSMS*'

            $resCol = @(
                foreach ($obj in $col) {
                    $obj | Select-PSFObject -TypeName "d365bap.tools.Ude.DbJit.Credential" `
                        -Property *,
                    @{  Name       = "Password"
                        Expression = {
                            ($creds | Where-Object UserName -eq $($obj.Username) | Select-Object -First 1 -ExpandProperty Password)
                        }
                    }
                }
            )
        }
        else {
            $resCol = $col | Select-PSFObject -TypeName "d365bap.tools.Ude.DbJit.Credential" `
                -Property *
        }

        $resCol
    }
}