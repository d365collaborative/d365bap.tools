
<#
    .SYNOPSIS
        Start a database refresh between two environments
        
    .DESCRIPTION
        Enables the user to start a database refresh between two environments in the same tenant.
        
        The source and target environments must both be either managed or unmanaged.
        
    .PARAMETER SourceEnvironmentId
        Id of the source environment that you want to copy the database from.
        
    .PARAMETER TargetEnvironmentId
        Id of the target environment that you want to copy the database to.
        
    .PARAMETER CopyType
        Type of copy to perform.
        
        Valid values are "FullCopy" and "TransactionLess".
        
        Default is "FullCopy".
        
    .PARAMETER IncludeAuditData
        Instructs the cmdlet to include audit data in the copy.
        
    .PARAMETER AdvancedFnO
        Instructs the cmdlet to execute an advanced copy for Finance and Operations.
        
    .EXAMPLE
        PS C:\> Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat*
        
        This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
        It defaults to a full copy.
        
    .EXAMPLE
        PS C:\> Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType FullCopy
        
        This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType TransactionLess
        
        This will start a transaction-less database refresh from the environment with id containing "dev" to the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType FullCopy -IncludeAuditData
        
        This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
        It will include audit data in the copy.
        
    .EXAMPLE
        PS C:\> Start-BapDatabaseRefresh -SourceEnvironmentId *dev* -TargetEnvironmentId *uat* -CopyType FullCopy -AdvancedFnO
        This will start a full copy database refresh from the environment with id containing "dev" to the environment with id containing "uat".
        It will execute an advanced copy for Finance and Operations.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Start-BapDatabaseRefresh {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [Alias("Source")]
        [string] $SourceEnvironmentId,

        [Alias("Target")]
        [string] $TargetEnvironmentId,

        [ValidateSet("FullCopy", "TransactionLess")]
        [string] $CopyType = "FullCopy",

        [switch] $IncludeAuditData,

        [switch] $AdvancedFnO
    )

    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envSource = Get-BapEnvironment -EnvironmentId $SourceEnvironmentId | Select-Object -First 1
        $envTarget = Get-BapEnvironment -EnvironmentId $TargetEnvironmentId | Select-Object -First 1

        if ($null -eq $envSource -or $null -eq $envTarget) {
            $messageString = "Could not find either <c='em'>source</c> or <c='em'>target</c> environments. Please verify the Ids and try again, or list available environments using <c='em'>Get-BapEnvironment</c>."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environments were NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        if ($envSource.Managed -ne $envTarget.Managed) {
            $messageString = "The Managed state between environments is different. Database refresh is not supported for environments with different Managed states."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because one of the environments Managed state is different." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $payload = [PSCustomObject][ordered]@{
            sourceEnvironmentId                        = $envSource.PpacEnvId
            targetEnvironmentName                      = $envTarget.PpacEnvName
            executeAdvancedCopyForFinanceAndOperations = $AdvancedFnO.IsPresent
            copyType                                   = if ($CopyType -eq "FullCopy") { $CopyType } else { "TransactionLess" }
            skipAuditData                              = -not $IncludeAuditData
        } | ConvertTo-Json -Depth 10

        $payload
        return
        $localUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/$($envSource.PpacEnvId)/copyTo?api-version=2021-04-01"
        
        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersBapApi `
            -ContentType "application/json" `
            -Body $payload
    }
    
    end {
        
    }
}