# Get-FscmOdataToken Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Get-FscmOdataToken` cmdlet that returns an FnO-scoped Azure access token as a typed `PSCustomObject` exposing `Token` and `BearerToken`.

**Architecture:** Reuse `Get-FscmOdata`'s authentication flow (resolve environment via `Get-BapEnvironment`, derive the FnO base URI, mint a token with `Get-AzAccessToken`), then emit a `PSCustomObject` stamped as `D365Bap.Tools.FscmOdataToken` via `Select-PSFObject`. A list Format `.ps1xml` gives it a friendly display and is registered in the module manifest.

**Tech Stack:** PowerShell, PSFramework (`Select-PSFObject`, `Write-PSFMessage`, `Stop-PSFFunction`), Az.Accounts (`Get-AzAccessToken`).

---

## File Structure

- `d365bap.tools/functions/Get-FscmOdataToken.ps1` — the public cmdlet. One responsibility: mint and return the token object.
- `d365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml` — list view for the output type.
- `d365bap.tools/d365bap.tools.psd1` — register the Format file (one line added to `FormatsToProcess`).

**Note:** Pester tests and the `docs/*.md` help file are intentionally out of scope — the author has separate tooling that generates them.

---

## Task 1: Create the Get-FscmOdataToken function

**Files:**
- Create: `d365bap.tools/functions/Get-FscmOdataToken.ps1`

- [ ] **Step 1: Write the function file**

Create `d365bap.tools/functions/Get-FscmOdataToken.ps1` with exactly this content:

```powershell

<#
    .SYNOPSIS
        Get an OData access token for a Finance and Operations environment.
        
    .DESCRIPTION
        Acquires an Azure access token scoped to the Finance and Operations (FnO) OData resource of the specified environment, using the cached credentials in the local Azure PowerShell context.
        
        Returns both the raw token and a ready-to-use bearer token string, so the token can be inspected or reused in custom REST calls against the FnO endpoints.
        
        The token is returned in plain text. Handle the output accordingly.
        
    .PARAMETER EnvironmentId
        The ID of the environment to acquire the token for.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .EXAMPLE
        PS C:\> Get-FscmOdataToken -EnvironmentId "ContosoEnv"
        
        This command acquires an OData access token for the environment "ContosoEnv" and returns an object with the raw Token and a ready-to-use BearerToken.
        
    .EXAMPLE
        PS C:\> $token = Get-FscmOdataToken -EnvironmentId "ContosoEnv"
        PS C:\> Invoke-RestMethod -Uri $uri -Headers @{ Authorization = $token.BearerToken }
        
        This command acquires an OData access token for the environment "ContosoEnv" and uses the BearerToken property directly in the Authorization header of a custom REST call.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataToken {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        [PSCustomObject]@{ Token = $tokenValue } | `
            Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataToken" `
            -Property "Token",
        @{ Name = "BearerToken"; Expression = { "Bearer $($_.Token)" } }
    }
    
    end {
        
    }
}
```

- [ ] **Step 2: Verify the file parses**

Run: `pwsh -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('d365bap.tools/functions/Get-FscmOdataToken.ps1', [ref]$null, [ref]$errs); if ($errs) { $errs; exit 1 } else { 'OK' }"`
Expected: `OK` (no parse errors).

- [ ] **Step 3: Commit**

```bash
git add d365bap.tools/functions/Get-FscmOdataToken.ps1
git commit -m "feat: add Get-FscmOdataToken function"
```

---

## Task 2: Create the list Format file

**Files:**
- Create: `d365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml`

- [ ] **Step 1: Write the Format file**

Create `d365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml` with exactly this content:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Configuration>
  <ViewDefinitions>
    <View>
            <Name>D365Bap.Tools.FscmOdataToken</Name>
            <ViewSelectedBy>
                <TypeName>D365Bap.Tools.FscmOdataToken</TypeName>
            </ViewSelectedBy>
            <ListControl>
                <ListEntries>
                    <ListEntry>
                        <ListItems>
                            <ListItem>
                                <PropertyName>Token</PropertyName>
                            </ListItem>
                            <ListItem>
                                <PropertyName>BearerToken</PropertyName>
                            </ListItem>
                        </ListItems>
                    </ListEntry>
                </ListEntries>
            </ListControl>
        </View>
  </ViewDefinitions>
</Configuration>
```

- [ ] **Step 2: Verify the XML is well-formed**

Run: `pwsh -NoProfile -Command "[xml](Get-Content -Raw 'd365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml'); 'OK'"`
Expected: `OK` (no XML load exception).

- [ ] **Step 3: Commit**

```bash
git add d365bap.tools/xml/formats/list/D365Bap.Tools.FscmOdataToken.List.Format.ps1xml
git commit -m "feat: add list format for D365Bap.Tools.FscmOdataToken"
```

---

## Task 3: Register the format file and export the function in the manifest

**Files:**
- Modify: `d365bap.tools/d365bap.tools.psd1` (two insertions: one in `FormatsToProcess`, one in `FunctionsToExport`)

- [ ] **Step 1: Add the format registration line**

In `d365bap.tools/d365bap.tools.psd1`, find this line in the `FormatsToProcess` array:

```
		'xml\formats\list\D365Bap.Tools.FscmOdataEntity.List.Format.ps1xml',
```

Insert a new line immediately after it so the two lines read:

```
		'xml\formats\list\D365Bap.Tools.FscmOdataEntity.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.FscmOdataToken.List.Format.ps1xml',
```

Preserve the existing tab indentation used in the file.

- [ ] **Step 2: Add the function export line**

In the same file, find these lines in the `FunctionsToExport` array (note the leading-comma style):

```
		, 'Get-FscmOdata'
		, 'Get-FscmOdataEntity'
```

Insert a new line immediately after `'Get-FscmOdataEntity'` so the three lines read:

```
		, 'Get-FscmOdata'
		, 'Get-FscmOdataEntity'
		, 'Get-FscmOdataToken'
```

Preserve the existing tab indentation and the leading-comma style.

- [ ] **Step 3: Verify the manifest still loads**

Run: `pwsh -NoProfile -Command "$m = Import-PowerShellDataFile 'd365bap.tools/d365bap.tools.psd1'; if ($m.FunctionsToExport -notcontains 'Get-FscmOdataToken') { throw 'not exported' }; 'OK'"`
Expected: `OK` (the manifest parses and now exports the function).

- [ ] **Step 4: Commit**

```bash
git add d365bap.tools/d365bap.tools.psd1
git commit -m "feat: register Get-FscmOdataToken format and export in manifest"
```

---

## Task 4: End-to-end module import verification

**Files:** none (verification only)

- [ ] **Step 1: Import the module and confirm the command is exported and typed correctly**

Run: `pwsh -NoProfile -Command "Import-Module ./d365bap.tools/d365bap.tools.psd1 -Force; $c = Get-Command Get-FscmOdataToken; if (-not $c) { throw 'command missing' }; $p = $c.Parameters['EnvironmentId']; if (-not $p.Attributes.Mandatory) { throw 'EnvironmentId not mandatory' }; 'OK'"`
Expected: `OK`. If the module has other import prerequisites (PSFramework, Az) that are not installed in the environment, note them but a successful import with `Get-Command` returning the function is the pass condition.

- [ ] **Step 2: No commit** — this task only verifies. If it surfaces a problem, fix it in the relevant earlier task and re-commit there.

---

## Self-Review

**Spec coverage:**
- FnO-scoped token requiring `-EnvironmentId` → Task 1 (environment resolution + `Get-AzAccessToken -ResourceUrl $baseUri`).
- Output `PSCustomObject` with `Token` + `BearerToken`, typed `D365Bap.Tools.FscmOdataToken` → Task 1 (`Select-PSFObject -TypeName`).
- Guard clause for unresolvable environment → Task 1 (`Write-PSFMessage` + `Stop-PSFFunction`).
- Plaintext-token note → Task 1 (`.DESCRIPTION`).
- List Format file → Task 2.
- Manifest registration (one line) → Task 3.
- Tests / docs.md / Excel / custom resource → explicitly out of scope, no task. Correct per spec.

**Placeholder scan:** No TBD/TODO; every code and XML block is complete and literal.

**Type consistency:** The type name `D365Bap.Tools.FscmOdataToken` is identical across the function (`Select-PSFObject -TypeName`), the Format file (`<Name>` and `<TypeName>`), and the manifest path. Property names `Token` and `BearerToken` match between the function output and the Format `<PropertyName>` entries.
