
<#
    .SYNOPSIS
        Get users/members from security role
        
        
    .DESCRIPTION
        Enables the user to fetch all users/members from the security role in the environment
        
        Utilizes the built-in "roles" OData entity
        
        Allows the user to include all users/members, based on those who has the ApplicationId property filled
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
        
        
    .PARAMETER SecurityRoleId
        The id of the security role that you want to work against
        
        This can be obtained from the Get-BapEnvironmentSecurityRole cmdlet
        
    .PARAMETER UserId
        The (SystemUser)Id or email of the user that you want to filter on
        
        This can be obtained from the Get-BapEnvironmentUser cmdlet
        
        Default value is "*" - which translates into all available users/members
        
        Wildcard search is supported
        
    .PARAMETER IncludeAppIds
        Instruct the cmdlet to include all users that are members of the security role
        
        Simply includes those who has the ApplicationId property filled
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRoleMember -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -SecurityRoleId 'System Administrator'
        
        This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.
        
        Sample output:
        Email                          Name                           AppId                SystemUserId
        -----                          ----                           -----                ------------
        d365admin@contoso.com          # D365Admin                                         58879b65-65ca-45f7-bf8e-9550e241083e
        crmoln2@microsoft.com          Delegated Admin                                     58879b65-65ca-47f5-bf8e-9550e241083e
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator'
        
        This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.
        
        Sample output:
        Email                          Name                           AppId                SystemUserId
        -----                          ----                           -----                ------------
        d365admin@contoso.com          # D365Admin                                         58879b65-65ca-45f7-bf8e-9550e241083e
        crmoln2@microsoft.com          Delegated Admin                                     58879b65-65ca-47f5-bf8e-9550e241083e
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator' -UserId '*@contoso.com'
        
        This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.
        It will only include the ones that have an email address that contains '@contoso.com'.
        
        Sample output:
        Email                          Name                           AppId                SystemUserId
        -----                          ----                           -----                ------------
        d365admin@contoso.com          # D365Admin                                         58879b65-65ca-45f7-bf8e-9550e241083e
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator' -IncludeAppIds
        
        This will fetch all users that are members of the security role 'System Administrator' from the environment.
        It will include the ones with the ApplicationId property filled.
        
        Sample output:
        Email                          Name                           AppId                SystemUserId
        -----                          ----                           -----                ------------
        CatalogServiceEur@onmicrosoft… # CatalogServiceEur            ac22509c-8d51-4169-… 330297ba-cbf6-ed11-8849-6045bd8e42bc
        CCaaSCRMClient@onmicrosoft.com # CCaaSCRMClient               edfdd43b-45b9-498b-… f4f45a4b-f8b7-ed11-9886-6045bd8e42bc
        d365admin@contoso.com          # D365Admin                                         58879b65-56ca-45f7-bf8e-9550e241083e
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator' -AsExcelOutput
        
        This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentSecurityRoleMember {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (mandatory = $true)]
        [string] $SecurityRoleId,

        [string] $UserId = "*",

        [switch] $IncludeAppIds,

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $secRoleObj = Get-BapEnvironmentSecurityRole -EnvironmentId $EnvironmentId -Name $SecurityRoleId | Select-Object -First 1

        if ($null -eq $secRoleObj) {
            $messageString = "The supplied SecurityRoleId: <c='em'>$SecurityRoleId</c> didn't return any matching security details from the Environment. Please verify that the EnvironmentId & SecurityRoleId is correct - try running the <c='em'>Get-BapEnvironment</c> or <c='em'>Get-BapEnvironmentSecurityRole</c> cmdlets."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $resRoleObj = Invoke-RestMethod -Method Get -Uri $($baseUri + "/api/data/v9.2/roles($($secRoleObj.Id))?`$expand=systemuserroles_association") -Headers $headersWebApi
        
        $resCol = @(
            $resRoleObj.systemuserroles_association | Select-PSFObject -TypeName "D365Bap.Tools.User" `
                -ExcludeProperty "@odata.etag" `
                -Property "systemuserid as Id",
            "internalemailaddress as Email",
            "fullname as Name",
            "applicationid as AppId",
            "azureactivedirectoryobjectid as EntraObjectId",
            @{Name = "NameSortable"; Expression = { $_.fullname.Replace("# ", "") } },
            *
        )

        $resCol = $resCol | Sort-Object -Property NameSortable
         
        if (-not $IncludeAppIds) {
            $resCol = $resCol | Where-Object applicationid -eq $null
        }

        if ($UserId.Contains("@")) {
            $resCol = $resCol | Where-Object Email -like $UserId
        }
        else {
            $resCol = $resCol | Where-Object Id -like $UserId
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }
    
    end {
        
    }
}