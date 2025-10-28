<#
.SYNOPSIS
Gets UDE cross-reference databases.

.DESCRIPTION
This function retrieves UDE cross-reference databases.

.PARAMETER Name
The name of the database to retrieve.

Supports wildcard patterns.

.EXAMPLE
PS C:\> Get-UdeXrefDb

This will retrieve all available UDE cross-reference databases.

.EXAMPLE
PS C:\> Get-UdeXrefDb -Name "db-123*"

This will retrieve the UDE cross-reference database with the specified name.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeXrefDb {
    [CmdletBinding()]
    [OutputType('[PsCustomObject]')]
    param (
        [string] $Name = "*"
    )

    end {
        $sqlCommand = Get-SqlCommand

        $sqlCommand.CommandText = @"
SELECT name FROM sys.databases
WHERE NAME NOT IN
('master', 'model', 'msdb', 'tempdb')
"@

        try {
            $sqlCommand.Connection.Open()
    
            $reader = $sqlCommand.ExecuteReader()

            while ($reader.Read() -eq $true) {
                $res = [PSCustomObject]@{
                    Name = "$($reader.GetString($($reader.GetOrdinal("NAME"))))"
                }

                if ($res.Name -NotLike $Name) { continue }

                $res
            }
        }
        catch {
            Write-PSFMessage -Level Host -Message "Something went wrong while working against the database" -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
        finally {
            $reader.close()
        }
        
        Dispose-SqlCommand -InputObject $sqlCommand
    }
}