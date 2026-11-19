<!--
topic: d365bap.tools.Namespaces
keywords: namespaces, abbreviations, command groups, bap, ppac, fscm, ppe, ude, unified, graph
-->

# Namespaces

Every command noun starts with a namespace that names the surface the command works against. The namespace tells you which portal, API or tool the command replaces.

The full command tables per namespace are on the [wiki](https://github.com/d365collaborative/d365bap.tools/wiki/Namespaces). List them yourself:

```pwsh
Get-Command -Module d365bap.tools -Noun Ppac*
```

## Bap

Business Application Platform. The oldest namespace: tenant-level and environment-level platform work. Get and compare environments and their D365 apps, install apps, manage virtual entities and enterprise policy links, install local helper tooling. See [Bap](Bap).

## Ppac

Power Platform Admin Center. Everything you would normally click through in the PPAC portal: environments, users, application users, teams, security roles, tables, D365 versions and platform updates, FinOps builds and assets, RBAC roles, DLP policies, capacity and admin mode.

## Fscm

Finance and Operations / Supply Chain Management. Commands that call the ERP directly through its public OData and REST endpoints: entity and action metadata, data queries, DMF entities, users, security roles and registered Entra applications. See [Fscm](Fscm).

## Ppe

Power Platform Environment. The maker surface of a single environment, the part you normally visit at [make.powerplatform.com](https://make.powerplatform.com): solutions, publishers, custom APIs and publish-all-customizations. See [Ppe](Ppe).

## Ude

Unified Developer Experience. The developer workstation: UDE config and connections, the Visual Studio credential cache, PackagesLocalDirectory, models, NuGet packages, cross-reference databases, database JIT access and SSMS. See [Ude](Ude).

## Unified

Unified Environment. The server-side environment object underneath a finance and operations installation: deploy new environments, manage modules and packages, maintenance windows, operation errors. See [Unified](Unified).

## Graph

Microsoft Graph. Entra ID lookups that support the security work: expand a security group into its members before assigning roles. See [Security](Security).

## Which namespace for which job

- "I administer tenants and environments" - Bap and Ppac.
- "I manage users or security roles" - [Security](Security) tells you which of the three role systems your task belongs to.
- "I import or author solutions" - Ppe.
- "I develop against a UDE" - Ude, with Unified for the server-side objects.
- "I read or update F&O data directly" - Fscm.

## Why namespaces at all

The same way pac cli groups admin, solution, connection and package subcommands: different surfaces need different tools and different internal plumbing, and the noun prefix keeps 170+ commands navigable. The abbreviation scheme is described on the [wiki](https://github.com/d365collaborative/d365bap.tools/wiki/Namespaces).
