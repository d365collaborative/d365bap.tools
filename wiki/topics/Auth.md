<!--
topic: d365bap.tools.Auth
keywords: authentication, auth, token, provider, azaccount, azcli, access token, login
-->

# Authentication

d365bap.tools does not have its own login. It mints access tokens through a configurable provider: Az.Accounts by default, or the Azure CLI.

## The two providers

AzAccount (default) uses the Az.Accounts module. Authenticate before calling commands:

```pwsh
Connect-AzAccount
```

In sessions where an interactive prompt cannot appear, use device authentication: Connect-AzAccount -UseDeviceAuthentication.

AzCli uses the az CLI instead. It must be on the path and logged in:

```pwsh
Invoke-BapInstallAzCli
az login
Set-BapToolsAuthProvider -AzCli
```

## Switching providers

Set-BapToolsAuthProvider validates before it switches: it checks that az exists and that the CLI has a tenant context, and keeps the current provider when validation fails. A successful switch persists your choice for future sessions, clears the in-memory token caches, and restarts the background FinOps version preload so it runs under the new provider.

```pwsh
Set-BapToolsAuthProvider -AzAccount
Get-BapToolsAuthProvider
```

## How commands get their tokens

Commands request tokens from the active provider for the resources they call: Power Platform management APIs for the Bap, Ppac and Unified namespaces, and the F&O environment itself for Fscm. Tokens are cached in memory for the session and cleared whenever you switch provider or [tenant](Tenants).

For raw header use against the ERP, Get-FscmOdataToken returns a token for a specific environment, with -AsBearerToken to format it as an Authorization header.

## Troubleshooting

- "No access token" or 401 responses - run Connect-AzAccount (or az login) and retry.
- Expired cached credentials during tenant switching - Switch-BapTenant -Force forces a fresh prompt.
- Az CLI context errors after switching providers - run az login --tenant <tenant id> --allow-no-subscriptions, then switch again.
- Tokens are session-scoped: a new PowerShell session always starts unauthenticated.
