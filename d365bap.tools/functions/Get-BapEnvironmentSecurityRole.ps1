
<#
    .SYNOPSIS
        Get Security Roles from environment
        
    .DESCRIPTION
        Get Security Roles from the Dataverse environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER Name
        Name of the Security Role that you want to work against
        
        Supports wildcard search
        
        Default value is "*" - which translates into all available Security Roles
        
    .PARAMETER IncludeAll
        Instruct the cmdlet to output all security roles, regardless of their type
        
        This will output all security roles, including the ones that are tied to Business Units, which at first glance might seem like duplicates
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will list all Security Roles from the Dataverse environment, by the EnvironmentId (guid).
        It will only list the Security Roles that are tied to the Environment.
        
        Sample output:
        Id                                   Name                                     IsManaged RoleType
        --                                   ----                                     --------- --------
        5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Feature  True      Environment
        1cbf96a1-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Feature  True      Environment
        d364ba1c-1bfb-eb11-94f0-0022482381ee Accounts Payable Admin                   True      Environment
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId *uat*
        
        This will list all Security Roles from the Dataverse environment, by the EnvironmentId (Name/Wildcard).
        It will only list the Security Roles that are tied to the Environment.
        
        Sample output:
        Id                                   Name                                     IsManaged RoleType
        --                                   ----                                     --------- --------
        5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Feature  True      Environment
        1cbf96a1-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Feature  True      Environment
        d364ba1c-1bfb-eb11-94f0-0022482381ee Accounts Payable Admin                   True      Environment
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -Name "*Administrator*"
        
        This will list all Security Roles, which matches the "*Administrator*" pattern, from the Dataverse environment.
        It will only list the Security Roles that are tied to the Environment.
        
        Sample output:
        Id                                   Name                                     IsManaged RoleType
        --                                   ----                                     --------- --------
        5a8c8098-b933-eb11-a813-000d3a8e7ded (Deprecated) Marketing Realtime Feature  True      Environment
        4758a2be-ccd8-ea11-a813-000d3a579805 App Profile Manager Administrator        True      Environment
        470a750f-d810-4ee7-a64a-ec002965c1ec Copilot for Service Administrator        True      Environment
        5e4a9faa-b260-e611-8106-00155db8820b IoT - Administrator                      True      Environment
        947229e9-e868-45cf-a361-5635eaf35ee2 Microsoft Copilot Administrator          True      Environment
        f7f90019-dc14-e911-816a-000d3a069ebd Omnichannel administrator                True      Environment
        6beb51c1-0eda-e911-a81c-000d3af75d63 Productivity tools administrator         True      Environment
        ebbb3fcb-fcd7-4bf8-9a48-7b5a9878e79e Sales Copilot Administrator              True      Environment
        abce3b01-5697-4973-9d7d-fca48ca84445 Survey Services Administrator(Deprecat   True      Environment
        63e389ae-bc55-ec11-8f8f-6045bd88b210 System Administrator                     True      Environment
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId *uat* -Name "System Administrator"
        
        This will list all Security Roles, which matches the "System Administrator" pattern, from the Dataverse environment.
        It will only list the Security Roles that are tied to the Environment.
        
        Sample output:
        Id                                   Name                                     IsManaged RoleType
        --                                   ----                                     --------- --------
        63e389ae-bc55-ec11-8f8f-6045bd88b210 System Administrator                     True      Environment
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId *uat* -Name "System Administrator" -IncludeAll
        
        This will list all Security Roles, which matches the "System Administrator" pattern, from the Dataverse environment.
        It will only list the Security Roles that are tied to the Environment.
        
        Sample output:
        Id                                   Name                                     IsManaged RoleType
        --                                   ----                                     --------- --------
        0cdbad8e-72e7-406c-ae38-8c4406caea59 System Administrator                     False     BusinessUnit
        63e389ae-bc55-ec11-8f8f-6045bd88b210 System Administrator                     True      Environment
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentSecurityRole -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will list all Security Roles from the Dataverse environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        General notes
#>
function Get-BapEnvironmentSecurityRole {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $IncludeAll,

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

        $baseUri = $envObj.LinkedMetaPpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }

        $searchById = Test-Guid -InputObject $Name
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resRoles = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/roles?$expand=businessunitid($select=businessunitid,_parentbusinessunitid_value)') -Headers $headersWebApi

        [System.Collections.Generic.List[System.Object]] $resCol = @()

        foreach ($roleObj in  $($resRoles.value | Sort-Object -Property name)) {
            if ($searchById) {
                if (-not ($roleObj.roleid -like $Name)) { continue }
            }
            else {
                if (-not ($roleObj.Name -like $Name)) { continue }
            }
                
            $tmp = $roleObj | Select-PSFObject -TypeName "D365Bap.Tools.Role" `
                -ExcludeProperty "@odata.etag" `
                -Property "roleid as Id", *,
            @{Name = "RoleType"; Expression = {
                    if ($null -eq $_.businessunitid._parentbusinessunitid_value) {
                        "Environment"
                    }
                    else {
                        "BusinessUnit"
                    }
                }
            }

            if ($IncludeAll) {
                $resCol.Add($tmp)
            }
            elseif ($tmp.RoleType -eq "Environment") {
                $resCol.Add($tmp)
            }
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