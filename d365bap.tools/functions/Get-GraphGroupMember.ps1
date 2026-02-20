
<#
    .SYNOPSIS
        Get members of a Security Group from Azure AD / Entra ID.
        
    .DESCRIPTION
        Retrieves members of a Security Group from Azure AD / Entra ID based on the supplied GroupId.
        
    .PARAMETER Group
        The ObjectId of the Security Group in Azure AD / Entra ID.
        
    .EXAMPLE
        PS C:\> Get-GraphGroupMember -Group "12345678-90ab-cdef-1234-567890abcdef"
        
        This command retrieves the members of the Security Group with the specified ObjectId.
        
    .EXAMPLE
        PS C:\> Get-GraphGroupMember -Group "FO-PPE-ENV-ADMINS"
        
        This command retrieves the members of the Security Group with the specified display name starting with "FO-PPE-ENV-ADMINS".
        If multiple groups match, it will take the first one returned by Graph API.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphGroupMember {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $Group
    )
    
    end {
        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
            "Content-Type"  = "application/json"
        }

        if (Test-Guid -InputObject $Group) {
            $uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=id eq '$Group'"
        }
        else {
            $uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName, '$Group')"
        }
        
        $groupObj = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi 4> $null | `
            Select-Object -ExpandProperty Value | `
            Select-Object -First 1

        if ($null -eq $groupObj) {
            $messageString = "The supplied Group: <c='em'>$Group</c> didn't return any matching Security Group in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Group was NOT found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
            return
        }
        
        $uriGraph = "https://graph.microsoft.com/v1.0/groups/$($groupObj.id)/transitiveMembers`?`$select=id,displayName,mail,userPrincipalName"

        $colMembers = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi 4> $null | `
            Select-Object -ExpandProperty Value

        if ($colMembers.Count -eq 0) {
            $messageString = "The Security Group: <c='em'>$($groupObj.id) | $($groupObj.displayName)</c> doesn't contain any members. Please verify that the Security Group has members."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the Security Group has no members." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        $colMembers
    }
}