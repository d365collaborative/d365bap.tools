
<#
    .SYNOPSIS
        Create a new security role in a given environment.
        
    .DESCRIPTION
        This cmdlet creates a new security role in a given Power Platform environment.
        
        It mimics the "Create New Role" experience of the security role editor in the Power Platform admin center, including the member privilege inheritance option and the option to include the App Opener privileges needed for running Model-Driven apps.
        
        The role is created in the root business unit of the environment, which makes the role available across all business units. Only roles in the root business unit can be modified.
        
        The role is created without any table privileges, unless the App Opener privileges are included.
        
    .PARAMETER EnvironmentId
        The ID of the environment to create the security role in.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The name of the security role that you want to create.
        
    .PARAMETER Description
        The description of the security role.
        
    .PARAMETER AppliesTo
        The description of the type of users the security role applies to.
        
    .PARAMETER SummaryOfCoreTablePrivileges
        The summary of the core table privileges of the security role.
        
        It is saved in the "summaryofcoretablepermissions" column of the security role.
        
    .PARAMETER MemberPrivilegeInheritance
        The member privilege inheritance that is used when the security role is assigned to a team.
        
        Valid options:
        "DirectUserAndTeamPrivileges" - Team members can inherit team privileges directly, based on the Direct User (Basic) access level.
        "TeamPrivilegesOnly" - Team members get all team privileges by default.
        
        The default value is "DirectUserAndTeamPrivileges".
        
    .PARAMETER IncludeAppOpenerPrivileges
        Instructs the cmdlet to include the App Opener privileges for running Model-Driven apps.
        
        The privileges are copied from the built-in "App Opener" security role in the environment.
        
    .EXAMPLE
        PS C:\> New-PpacSecurityRole -EnvironmentId "ContosoEnv" -Name "Monitoring Reader" -Description "Read access for monitoring" -AppliesTo "Monitoring users" -SummaryOfCoreTablePrivileges "Read access to monitoring tables"
        
        This command creates the security role "Monitoring Reader" in the environment "ContosoEnv".
        The role is created in the root business unit of the environment.
        The role is documented with a description, the type of users it applies to and a summary of its core table privileges.
        The role is created without any table privileges.
        
    .EXAMPLE
        PS C:\> New-PpacSecurityRole -EnvironmentId "ContosoEnv" -Name "Monitoring Reader" -Description "Read access for monitoring" -AppliesTo "Monitoring users" -SummaryOfCoreTablePrivileges "Read access to monitoring tables" -MemberPrivilegeInheritance "TeamPrivilegesOnly" -IncludeAppOpenerPrivileges
        
        This command creates the security role "Monitoring Reader" in the environment "ContosoEnv".
        Team members will get all team privileges by default, when the role is assigned to a team.
        It will include the App Opener privileges for running Model-Driven apps, copied from the built-in "App Opener" security role.
        
    .NOTES
        Author: Trygve Bechsgaard
#>
function New-PpacSecurityRole {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Name,

        [Parameter (Mandatory = $true)]
        [string] $Description,

        [Parameter (Mandatory = $true)]
        [string] $AppliesTo,

        [Parameter (Mandatory = $true)]
        [string] $SummaryOfCoreTablePrivileges,

        [ValidateSet('DirectUserAndTeamPrivileges', 'TeamPrivilegesOnly')]
        [string] $MemberPrivilegeInheritance = 'DirectUserAndTeamPrivileges',

        [switch] $IncludeAppOpenerPrivileges
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

        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $existingRole = Get-PpacSecurityRole `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Name `
            -IncludeAll | `
            Select-Object -First 1

        if ($null -ne $existingRole) {
            $messageString = "The supplied Name: <c='em'>$Name</c> is already a Security Role in the Power Platform environment. Please verify that the name is correct - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because a security role with the same name already exists." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # The role is always created in the root business unit - only roles in the
        # root business unit can be modified.
        $buObj = Get-CrmBusinessUnit -BaseUri $baseUri | `
            Where-Object IsRoot -eq $true | `
            Select-Object -First 1

        $payload = [ordered]@{
            name                        = $Name
            isinherited                 = $(if ($MemberPrivilegeInheritance -eq 'TeamPrivilegesOnly') { 0 } else { 1 })
            "businessunitid@odata.bind" = "/businessunits($($buObj.Id))"
        }

        if ($Description) { $payload.description = $Description }
        if ($AppliesTo) { $payload.appliesto = $AppliesTo }
        if ($SummaryOfCoreTablePrivileges) { $payload.summaryofcoretablepermissions = $SummaryOfCoreTablePrivileges }

        Invoke-RestMethod -Method Post `
            -Uri $($baseUri + "/api/data/v9.2/roles") `
            -Headers $headersWebApi `
            -ContentType "application/json" `
            -Body $($payload | ConvertTo-Json -Depth 10) `
            -ResponseHeadersVariable responseHeaders `
            -StatusCodeVariable statusRole > $null 4> $null

        if (-not ($statusRole -like "2*")) {
            $messageString = "Failed to create the Security Role: <c='em'>$Name</c> in the Power Platform environment. Please try creating the role manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because creating the Security Role failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $newRoleId = [regex]::Match("$($responseHeaders.'OData-EntityId')", '\(([0-9a-fA-F-]{36})\)').Groups[1].Value

        if ($IncludeAppOpenerPrivileges) {
            $appOpenerObj = Get-PpacSecurityRole `
                -EnvironmentId $envObj.PpacEnvId `
                -Name "App Opener" `
                -IncludeAll | `
                Select-Object -First 1

            if ($null -eq $appOpenerObj) {
                $messageString = "The built-in <c='em'>App Opener</c> Security Role wasn't found in the Power Platform environment. The App Opener privileges will NOT be included on the new Security Role. Please assign the privileges manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
                Write-PSFMessage -Level Important -Message $messageString
            }
            else {
                $colAppOpenerPrivileges = Invoke-RestMethod `
                    -Method Get `
                    -Uri $($baseUri + "/api/data/v9.2/RetrieveRolePrivilegesRole(RoleId=@roleId)?@roleId=$($appOpenerObj.PpacRoleId)") `
                    -Headers $headersWebApi 4> $null | `
                    Select-Object -ExpandProperty RolePrivileges

                $payloadPrivileges = [PsCustomObject][ordered]@{
                    Privileges = @($colAppOpenerPrivileges | ForEach-Object {
                            [PsCustomObject][ordered]@{
                                PrivilegeId = $_.PrivilegeId
                                Depth       = $_.Depth
                            }
                        })
                }

                Invoke-RestMethod -Method Post `
                    -Uri $($baseUri + "/api/data/v9.2/roles($newRoleId)/Microsoft.Dynamics.CRM.AddPrivilegesRole") `
                    -Headers $headersWebApi `
                    -ContentType "application/json" `
                    -Body $($payloadPrivileges | ConvertTo-Json -Depth 10) `
                    -StatusCodeVariable statusPrivileges > $null 4> $null

                if (-not ($statusPrivileges -like "2*")) {
                    $messageString = "Failed to include the App Opener privileges on the Security Role: <c='em'>$Name</c> in the Power Platform environment. Please assign the privileges manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
                    Write-PSFMessage -Level Important -Message $messageString
                }
            }
        }

        Get-PpacSecurityRole `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $newRoleId `
            -IncludeAll
    }

    end {

    }
}