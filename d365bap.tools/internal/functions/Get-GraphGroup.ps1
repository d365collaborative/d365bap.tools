
<#
    .SYNOPSIS
        Get a Security Group from Azure AD / Entra ID.
        
    .DESCRIPTION
        Retrieves a Security Group from Azure AD / Entra ID based on the supplied ObjectId or display name.
        
    .PARAMETER Group
        The ObjectId or display name of the Security Group in Azure AD / Entra ID.
        
    .EXAMPLE
        PS C:\> Get-GraphGroup -Group "env-123"
        
        This will retrieve the Security Group with the specified ObjectId or display name from Azure AD / Entra ID.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphGroup {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [Alias('EntraGroup')]
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
            # Validate that the Security Group exists in Azure AD / Entra ID
            $uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=id eq '$Group'"
        }
        else {
            $uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName, '$Group')"
        }

        $colGroups = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi | Select-Object -ExpandProperty Value

        if ($colGroups.Count -eq 0) {
            $messageString = "The supplied ObjectId / Entra Group: <c='em'>$Group</c> didn't return any matching Security Group in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Group was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        if ($colGroups.Count -gt 1) {
            $messageString = "The supplied ObjectId / Entra Group: <c='em'>$Group</c> returned multiple matching Security Groups in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Security Groups were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        }

        $colGroups[0]
    }
}