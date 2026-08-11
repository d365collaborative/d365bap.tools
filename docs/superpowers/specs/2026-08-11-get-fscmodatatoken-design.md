# Design: Get-FscmOdataToken

**Date:** 2026-08-11
**Author:** Mötz Jensen (@Splaxi)
**Status:** Approved for planning

## Summary

Add a new public cmdlet `Get-FscmOdataToken` to the `d365bap.tools` module. It acquires an
Azure access token scoped to a Finance and Operations (FnO) environment's OData resource and
returns it as a typed `PSCustomObject` exposing both the raw token and a ready-to-use bearer
string. The cmdlet reuses the exact authentication flow of `Get-FscmOdata` but stops at the
token, so callers can make their own REST calls, inspect the JWT, or reuse the header in other
tooling.

## Motivation

`Get-FscmOdata` already resolves an environment and mints an FnO-scoped token internally, but
that token is never surfaced to the caller. Users who need to issue custom requests against the
FnO OData/REST endpoints currently have no supported way to obtain the same token through the
module. `Get-FscmOdataToken` fills that gap with a minimal, focused cmdlet.

## Scope

**In scope**

- New function `Get-FscmOdataToken`.
- New list Format `.ps1xml` for the output type.
- One-line registration in the module manifest's `FormatsToProcess`.

**Out of scope**

- Pester test file — handled by the author's existing tooling.
- `docs/Get-FscmOdataToken.md` help file — handled by the author's existing tooling.
- Custom resource / ResourceUrl override — the token is always scoped to the FnO environment,
  identical to `Get-FscmOdata`.
- Excel output (`-AsExcelOutput`) — a single token object is not a meaningful spreadsheet.

## Behavior

### Signature

```powershell
Get-FscmOdataToken -EnvironmentId <string>
```

- `[CmdletBinding()]` with `[OutputType('System.Object[]')]`, matching sibling cmdlets.
- `-EnvironmentId` is mandatory. Accepts the environment name, the environment GUID (PPAC),
  or the LCS environment ID — same semantics as `Get-FscmOdata`.

### Output

A single `PSCustomObject` stamped with the type name `D365Bap.Tools.FscmOdataToken`, with
exactly two properties:

| Property      | Value                                                              |
|---------------|-------------------------------------------------------------------|
| `Token`       | Raw access token string, e.g. `eyJ0eXAi...`                       |
| `BearerToken` | `Bearer eyJ0eXAi...` — ready to drop into an `Authorization` header |

The token is returned in plaintext in memory. This is intentional and is the purpose of the
cmdlet; the `.DESCRIPTION` will state this explicitly.

## Implementation

Approach chosen: build the object and stamp its type via `Select-PSFObject -TypeName`, the
dominant idiom in this module (`Get-BapTenant`, `Get-FscmOdataEntity`, etc.). The
`begin`/`process`/`end` structure mirrors `Get-FscmOdata`.

### begin block — environment resolution and token acquisition

1. Resolve the environment:
   ```powershell
   $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1
   ```
2. If `$null`, emit the same guard as `Get-FscmOdata` (wording adapted):
   ```powershell
   $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
   Write-PSFMessage -Level Important -Message $messageString
   Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
   ```
3. `if (Test-PSFFunctionInterrupt) { return }`
4. Derive the base URI:
   ```powershell
   $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'
   ```
5. Acquire the token, mirroring `Get-FscmOdata`:
   ```powershell
   $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
   $tokenValue  = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
   ```

### process block — shape and emit

```powershell
if (Test-PSFFunctionInterrupt) { return }

[PSCustomObject]@{ Token = $tokenValue } |
    Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataToken" `
        -Property "Token",
    @{ Name = "BearerToken"; Expression = { "Bearer $($_.Token)" } }
```

### end block

Empty, matching module style.

### Header comment block

Full `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER EnvironmentId`, one or more `.EXAMPLE`, and
`.NOTES` (Author: Mötz Jensen (@Splaxi)). The `.DESCRIPTION` notes that the token is returned
in plaintext.

## Type Registration and Formatting

Following the `FscmOdataEntity` pattern.

### Format file

New file: `d365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml`

A `ListControl` view (a list reads better than a table for long token strings), selected by
type `D365Bap.Tools.FscmOdataToken`, displaying `Token` then `BearerToken`.

### Manifest wiring

Add one line to the `FormatsToProcess` array in `d365bap.tools/d365bap.tools.psd1`, in the
`list` section, positioned alphabetically near the other `FscmOdata*` entries:

```
'xml\formats\list\D365Bap.Tools.FscmOdataToken.List.Format.ps1xml',
```

No change to `TypesToProcess` (commented out and unused for these types). `Select-PSFObject
-TypeName` performs the type stamping at runtime, exactly as the other typed cmdlets rely on.

## Error Handling

- **Unresolvable `EnvironmentId`:** handled by the same `Write-PSFMessage` + `Stop-PSFFunction`
  guard used by `Get-FscmOdata`.
- **Token acquisition failures** from `Get-AzAccessToken`: surface naturally as terminating
  errors, matching sibling cmdlets, which do not wrap them.

## Files Touched

| File                                                                       | Action        |
|----------------------------------------------------------------------------|---------------|
| `d365bap.tools/functions/Get-FscmOdataToken.ps1`                           | new           |
| `d365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml` | new     |
| `d365bap.tools/d365bap.tools.psd1`                                         | edit (1 line) |
