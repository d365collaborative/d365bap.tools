# d365bap.tools

PowerShell module for Business Application Platform tasks (D365 Finance & Operations and Dataverse).
Gallery: [d365bap.tools](https://www.powershellgallery.com/packages/d365bap.tools). Requires PowerShell 7.6+.

```powershell
Install-Module -Name d365bap.tools -Scope CurrentUser
Get-Command -Module d365bap.tools
Get-Help <Command> -Detailed
```

First auth: `Set-PpacEndpoint` / `Set-PpacActiveEndpoint` (Service Principal). Live help: [wiki](https://github.com/d365collaborative/d365bap.tools/wiki).

`Invoke-UdeDbQuery` includes its SQL client. No SSMS, SQL PowerShell module, SDK, or separate driver installation is required. Request temporary Reader access and query an environment directly:

```powershell
Invoke-UdeDbQuery -EnvironmentId "dev-environment" -Query "SELECT DB_NAME() AS DatabaseName"
```

This uses your existing module authentication and public IP, waits for JIT propagation, and keeps SQL credentials in memory. `TUN.CredentialManager` is unnecessary for this flow. Use `-Role Writer` only when write access is needed. To reuse temporary credentials across queries, obtain them with `Get-UdeDbJit` and pass the result through `-JitCredential`. The existing `-Id` mode continues to use the SSMS credential cache and requires `TUN.CredentialManager`.

- Contributing and PR gates: [GATES.md](GATES.md)
- Agent guides: [AGENTS.md](AGENTS.md)
- Lint weight: [build/ps1-lint/WEIGHT.md](build/ps1-lint/WEIGHT.md)
- Lint hooks: [build/ps1-lint/HOOKS.md](build/ps1-lint/HOOKS.md)
- Dependencies: [gallery package details](https://www.powershellgallery.com/packages/d365bap.tools) · [dependency graph](https://github.com/d365collaborative/d365bap.tools/network/dependencies)
