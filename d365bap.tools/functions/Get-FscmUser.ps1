
<#
    .SYNOPSIS
        Get information about Finance and Operations users in a given environment.
        
    .DESCRIPTION
        This cmdlet retrieves information about Finance and Operations users in a given environment. It allows filtering by user name or ID, including or excluding Microsoft accounts, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve users from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER User
        The name or ID of the user to filter the users by.
        
        Can be either the user name, user ID or user principal name (UPN).
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER IncludeMicrosoftAccounts
        Instructs the cmdlet to include Microsoft accounts in the results. By default, Microsoft accounts are excluded.
        
        Microsoft accounts typically have aliases (UPNs) ending with domains like @dynamics.com, @microsoft.com, @onmicrosoft.com, @devtesttie.ccsctp.net or @capintegration01.onmicrosoft.com.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved user information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe"
        
        This command retrieves the Finance and Operations user with the user name "john.doe" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -User "*john*"
        
        This command retrieves all Finance and Operations users with user names, user IDs or UPNs matching "*john*" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -User "john@contoso.com"
        
        This command retrieves the Finance and Operations user with the UPN "john@contoso.com" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -IncludeMicrosoftAccounts
        
        This command retrieves all Finance and Operations users, including Microsoft accounts, from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmUser -EnvironmentId "ContosoEnv" -IncludeMicrosoftAccounts -AsExcelOutput
        
        This command retrieves all Finance and Operations users, including Microsoft accounts, from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmUser {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $User = "*",

        [switch] $IncludeMicrosoftAccounts,

        [switch] $AsExcelOutput
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
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $localUri = $baseUri + '/data/SystemUsers'
        $colUsersRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $colUsers = $colUsersRaw | Where-Object {
            ($_.UserID -like $User -or $_.UserID -eq $User) `
                -or ($_.UserName -like $User -or $_.UserName -eq $User) `
                -or ($_.Alias -like $User -or $_.Alias -eq $User)
        } | Sort-Object -Property UserID

        if (-not $IncludeMicrosoftAccounts) {
            $colUsers = $colUsers | Where-Object {
                -not (
                    $_.Alias -like "*@dynamics.com" `
                        -or $_.Alias -like "*@microsoft.com" `
                        -or $_.Alias -like "*@onmicrosoft.com" `
                        -or $_.Alias -like "*@devtesttie.ccsctp.net" `
                        -or $_.Alias -like "*@capintegration01.onmicrosoft.com"
                )
            }
        }

        $resCol = @(
            $colUsers | Select-PSFObject -TypeName "D365Bap.Tools.FscmUser" `
                -ExcludeProperty "@odata.etag", "Language", "UserID" `
                -Property "UserID as FscmUserId",
            "UserID as UserId",
            "Company as LegalEntity",
            "UserName as Name",
            "Alias as Upn",
            "UserInfo_language as Language",
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmUser"
            return
        }

        $resCol
    }
    
    end {
        
    }
}