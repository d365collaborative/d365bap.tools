<!--
topic: d365bap.tools
keywords: d365bap, bap, power platform, dataverse, finance and operations, getting started
-->

# d365bap.tools

d365bap.tools automates admin and developer work across Dynamics 365 Finance and Operations and the Power Platform environments it runs on.

## What it covers

- Tenant and environment administration, the way you would do it in the [PPAC portal](https://admin.powerplatform.microsoft.com) - see [Bap](Bap) and the `Ppac` namespace.
- The F&O ERP itself, through its OData and REST endpoints - see [Fscm](Fscm).
- Solutions, publishers and custom APIs on the maker surface - see [Ppe](Ppe).
- Unified developer environments (UDE) and the local workstation tooling around them - see [Ude](Ude) and [Unified](Unified).
- Security across three different role systems - see [Security](Security).
- Governance policies across tenant, environment group and environment scopes - see [Policies](Policies).

## Requirements

PowerShell 7.6 or newer. The bundled Power Platform SDK needs the .NET 10 runtime that ships with PowerShell 7.6. Install-Module pulls the declared dependencies in automatically: PSFramework (configuration, logging, tab completion), ImportExcel (Excel export switches) and Az.Accounts (default token minting).

```pwsh
Install-Module -Name d365bap.tools -Scope CurrentUser
Import-Module -Name d365bap.tools
```

## First steps

Authenticate with Connect-AzAccount (the default provider) and register the tenant you work in. Then work one session at a time, or switch between saved tenants:

```pwsh
Connect-AzAccount

Set-BapTenantDetail -Id "Contoso" -Upn "user@contoso.com" -TenantId "12345678-1234-1234-1234-123456789012"
Switch-BapTenant -Id "Contoso"
```

Read [Auth](Auth) for token providers and [Tenants](Tenants) for the tenant registry and switching semantics.

## What persists and what does not

Settings that survive a new PowerShell session, stored with the PSFramework user scope: the token minting provider ([Auth](Auth)), saved tenant details ([Tenants](Tenants)) and cached database JIT credentials ([Ude](Ude)).

State that lives only in the current session: in-memory token caches, the current UDE environment, and any config value you set without registering it.

## Finding your way around

```pwsh
Get-Command -Module d365bap.tools -Noun Ppac*
Get-Help Get-PpacUser -Detailed
Get-Help about_d365bap.tools.Namespaces
```

Tab completion is available on most commands, backed by live data: environment names, tenants, tables, security roles and FinOps versions complete as you type.

## Concepts

The command groups are explained in [Namespaces](NamespacesConcept). Long-running platform work follows one pattern, described in [Operations](Operations). Every conceptual topic is also available from any PowerShell session with Get-Help about_d365bap.tools.<Topic>.
