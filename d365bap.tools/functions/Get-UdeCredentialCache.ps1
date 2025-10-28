
<#
    .SYNOPSIS
        Gets UDE credential cache information.
        
    .DESCRIPTION
        This function retrieves cached UDE credentials stored in an encrypted file used by the CRM Developer Toolkit.
        
    .PARAMETER Path
        The path to the CRM Developer Toolkit folder.
        
        Defaults to the standard location in the user's AppData folder.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.

        Will include all properties, including those not shown by default in the console output.
        
    .EXAMPLE
        PS C:\> Get-UdeCredentialCache
        
        This will retrieve the UDE credential cache information.
        
    .EXAMPLE
        PS C:\> Get-UdeCredentialCache -AsExcelOutput
        
        This will retrieve the UDE credential cache information and export it to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeCredentialCache {
    [CmdletBinding()]
    param (
        [string] $Path = "$env:APPDATA\Microsoft\CRMDeveloperToolKit",

        [switch] $AsExcelOutput
    )

    begin {
        $pathCache = Get-ChildItem -Path "$Path\*.tokens.dat" | Select-Object -First 1 -ExpandProperty FullName

        if ($null -eq $pathCache) {
            $messageString = "The encrypted cache file was not found. Make sure that the <c='em'>'$Path'</c> is pointing to the correct location of the CRMDeveloperToolKit."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because the encrypted cache file was not found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        # Read the encrypted bytes from the file
        $encryptedBytes = [System.IO.File]::ReadAllBytes($pathCache)
    
        # Unprotect the data
        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedBytes,
            $null,  # No additional entropy
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )

        # Step 2: Parse with BinaryReader AFTER decryption
        $memoryStream = [System.IO.MemoryStream]::new($decryptedBytes)
        $binaryReader = [System.IO.BinaryReader]::new($memoryStream, [System.Text.Encoding]::UTF8)

        $strings = [System.Collections.Generic.List[string]]::new()

        while ($memoryStream.Position -lt $memoryStream.Length) {
            $strings.Add($binaryReader.ReadString())
        }

        $resCol = @(
            for ($i = 0; $i -lt $strings.Count; $i += 2) {
                $tokenObj = $strings[$i + 1] | ConvertFrom-Json

                if ($null -eq $tokenObj) {
                    continue
                }

                [PsCustomObject][ordered]@{
                    ConnectionUri = $tokenObj.ResourceInResponse
                    Upn           = $tokenObj.Result.UserInfo.DisplayableId
                    PpacEnvUri    = ($tokenObj.ResourceInResponse).Replace("api.", "")
                    TenantId      = $tokenObj.Result.TenantId
                } | Select-PSFObject -TypeName 'D365Bap.Tools.UdeCredentialCache'
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }

    end {
    }
}