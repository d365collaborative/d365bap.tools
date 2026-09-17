
<#
    .SYNOPSIS
        Retrieves information about the available azure tenant.
        
    .DESCRIPTION
        This function retrieves information about the available azure tenants based on cached credentials in the local Azure PowerShell context.
        
    .PARAMETER Upn
        Specifies the User Principal Name (UPN) of the user account to filter the results.
        
        Supports wildcard patterns.
        
        Defaults to "*" which means all UPNs.
        
    .PARAMETER TenantId
        Specifies the Tenant ID to filter the results.
        
        Supports wildcard patterns.
        
        Defaults to "*" which means all Tenant IDs.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .PARAMETER AsHashTable
        Instructs the function to export the results to a hashtable.
        
    .EXAMPLE
        PS C:\> Get-BapTenant
        
        This will retrieve all available tenants based on cached Azure PowerShell credentials.
        
    .EXAMPLE
        PS C:\> Get-BapTenant -Upn "alex@contoso.com"
        
        This will retrieve the tenant information for the specified UPN.
        It will only return results where the UPN matches "alex@contoso.com".
        
    .EXAMPLE
        PS C:\> Get-BapTenant -TenantId "12345678-90ab-cdef-1234-567890abcdef"
        
        This will retrieve the tenant information for the specified Tenant ID.
        It will only return results where the Tenant ID matches "12345678-90ab-cdef-1234-567890abcdef".
        
    .EXAMPLE
        PS C:\> Get-BapTenant -AsExcelOutput
        
        This will export the retrieved tenant information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-BapTenant -AsHashTable
        
        This will export the retrieved tenant information to a hashtable.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
#>
function Get-BapTenant {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType('System.Object[]')]
    param (
        [Parameter()]
        [Alias("Login")]
        [Alias("User")]
        [Alias("Username")]
        [string] $Upn = "*",
        
        [Parameter()]
        [string] $TenantId = "*",

        [Parameter(ParameterSetName = 'Excel')]
        [switch] $AsExcelOutput,

        [Parameter(ParameterSetName = 'HashTable')]
        [switch] $AsHashTable
    )

    begin {
        try {
            $tenantDomains = @(Get-AzTenant -ErrorAction Stop)
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Get-AzTenant failed with: $($_.Exception.Message). Tenant names will be empty."
            $tenantDomains = @()
        }
    }
    
    process {
        $azContexts = $null
        try {
            $azContexts = @(Get-AzContext -ListAvailable -ErrorAction Stop)
        }
        catch {
            # Az.Accounts (seen in 2.17.0) throws NullReferenceException from
            # Get-AzContext -ListAvailable when any cached context has no
            # subscription (e.g. a tenant-only login created via
            # Connect-AzAccount -Tenant ... -SkipContextPopulation $true).
            # It sorts by Subscription.Name without a null check, so one
            # subscription-less entry breaks the whole listing. Fall back to
            # the cached profile file, which contains the same Account/Tenant
            # pairs Get-BapTenant needs.
            Write-PSFMessage -Level Verbose -Message "Get-AzContext -ListAvailable failed with: $($_.Exception.Message). Falling back to cached Azure profile."
            $azContexts = @()

            $contextFiles = @()
            if (-not [string]::IsNullOrWhiteSpace($env:AZURE_CONFIG_DIR)) {
                $contextFiles += Join-Path $env:AZURE_CONFIG_DIR "AzureRmContext.json"
            }
            if ($HOME) {
                $contextFiles += Join-Path (Join-Path $HOME ".Azure") "AzureRmContext.json"
            }
            if ($env:USERPROFILE) {
                $contextFiles += Join-Path (Join-Path $env:USERPROFILE ".Azure") "AzureRmContext.json"
            }
            $contextFile = $contextFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) } | Select-Object -First 1

            if ($contextFile) {
                try {
                    $cachedProfile = Get-Content -Raw -Path $contextFile -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                    foreach ($prop in $cachedProfile.Contexts.PSObject.Properties) {
                        $entry = $prop.Value
                        if ($null -eq $entry -or $null -eq $entry.Tenant -or [string]::IsNullOrWhiteSpace($entry.Tenant.Id)) { continue }
                        if ($null -eq $entry.Account -or [string]::IsNullOrWhiteSpace($entry.Account.Id)) { continue }

                        $azContexts += [PSCustomObject]@{
                            Account = [PSCustomObject]@{ Id = $entry.Account.Id }
                            Tenant  = [PSCustomObject]@{ Id = $entry.Tenant.Id }
                        }
                    }
                }
                catch {
                    Write-PSFMessage -Level Verbose -Message "Failed to read cached Azure contexts from '$contextFile': $($_.Exception.Message)"
                }
            }

            if ($azContexts.Count -eq 0) {
                # Last resort: at least return the current context so the
                # cmdlet still works when the cache file is missing.
                try {
                    $current = Get-AzContext -ErrorAction Stop
                    if ($null -ne $current -and $null -ne $current.Tenant -and $current.Tenant.Id) {
                        $azContexts = @($current)
                    }
                }
                catch {
                    Write-PSFMessage -Level Verbose -Message "Get-AzContext (current) also failed with: $($_.Exception.Message)"
                }
            }
        }

        $cachedCreds = @(
            ($azContexts | `
                Where-Object { $null -ne $_.Tenant.Id  } | `
                Group-Object { $_.Tenant.Id }, { $_.Account.Id }) | `
                ForEach-Object { $_.Group[0] }
        )

        $resCol = @(
            foreach ($credObj in $cachedCreds) {
                if (-not ($credObj.Account.Id -like $Upn)) { continue }
                if (-not ($credObj.Tenant.Id -like $TenantId)) { continue }

                $credObj | Select-PSFObject -TypeName "D365Bap.Tools.TenantCredential" `
                    -Property @{ Name = "Upn"; Expression = { $_.Account.Id } },
                @{ Name = "TenantId"; Expression = { $_.Tenant.Id } },
                @{ Name = "TenantName"; Expression = { $tenantDomains | Where-Object id -eq $_.Tenant.Id | Select-Object -ExpandProperty name -First 1 } }
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapTenant"
            return
        }
        elseif ($AsHashTable) {
            $resCol | ConvertTo-PSFHashtable
            return
        }

        $resCol
    }
    
    end {
        
    }
}