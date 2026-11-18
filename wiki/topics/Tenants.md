<!--
topic: d365bap.tools.Tenants
keywords: tenant, tenants, switch, context, azure ad, entra, tenant details
-->

# Tenants

d365bap.tools keeps a local registry of named tenants so that switching between them is one command. The registry is stored in the PSFramework user scope and survives new sessions.

## The registry

Each entry has a friendly Id you choose, the UPN you log in with, the tenant id, and an optional friendly name:

```pwsh
Set-BapTenantDetail -Id "Contoso" -Upn "user@contoso.com" -TenantId "12345678-1234-1234-1234-123456789012" -TenantName "Contoso Unlimited"
```

- Get-BapTenant - discover the Azure tenants your account can reach, including as a hashtable for splatting into Set-BapTenantDetail.
- Get-BapTenantDetail - list the registered entries.
- Remove-BapTenantDetail - remove one entry.
- Set-BapTenantDetail - add or update an entry.

## Switching

Switch-BapTenant -Id "Contoso" reuses a cached login when one is valid, and prompts for login only when the token is expired or missing. -Force always prompts. A switch clears the in-memory token caches and restarts the background environment-name refresh task (it runs every 15 minutes and feeds environment-name tab completion).

```pwsh
$details = Get-BapTenant -TenantId "12345678-1234-1234-1234-123456789012" -AsHashTable
Set-BapTenantDetail -Id "Contoso" @details
Switch-BapTenant -Id "Contoso"
```

Under the AzCli provider the same flow works through the az CLI context instead of Az.Accounts contexts; see [Auth](Auth).

## Multi-tenant workflows

Register every tenant you work in, then switch before each batch of work. Commands mint tokens for the tenant that is currently active, so forgetting to switch is the most common cause of "environment not found" errors in a multi-tenant setup. The tenant Id parameter of Set-BapTenantDetail and Switch-BapTenant completes from your registry.
