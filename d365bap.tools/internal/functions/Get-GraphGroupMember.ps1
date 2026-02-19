
<#
    .SYNOPSIS
        Get members of a Security Group from Azure AD / Entra ID.
        
    .DESCRIPTION
        Retrieves members of a Security Group from Azure AD / Entra ID based on the supplied GroupId.
        
    .PARAMETER GroupId
        The ObjectId of the Security Group in Azure AD / Entra ID.
        
    .EXAMPLE
        PS C:\> Get-GraphGroupMember -GroupId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        
        This command retrieves the members of the Security Group with the specified ObjectId.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphGroupMember {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $GroupId
    )
    
    end {
        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
            "Content-Type"  = "application/json"
        }

        $uriGraph = "https://graph.microsoft.com/v1.0/groups/$($GroupId)/transitiveMembers`?`$select=id,displayName,mail,userPrincipalName"

        $colMembers = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi 4> $null | `
            Select-Object -ExpandProperty Value

        if ($colMembers.Count -eq 0) {
            $messageString = "The Security Group: <c='em'>$($GroupId)</c> doesn't contain any members. Please verify that the Security Group has members."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the Security Group has no members." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        $colMembers
    }
}