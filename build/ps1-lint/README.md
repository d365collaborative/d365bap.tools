# ps1-lint (vendored)

PowerShell lint hook scripts for `prek.toml`. They started as a copy of the
PS1 hooks from an internal-only module and are maintained in this repo from
here on — no submodule, no sync back. Rule changes happen here via normal PRs.

What runs on `**.ps1`:
- `psscriptanalyzer/Run.ps1` — native PSScriptAnalyzer (Error + Warning,
  fails on Error) plus repo rules: `PSOnlyCommentBasedHelp`,
  `PSHelpSynopsis/Description/Parameter/Notes/Example`,
  `PSAvoidCommandAliases` / `PSAvoidParameterAliases`,
  `PSUseSupportsWildcards`, `PSAvoidRedundantParameterAttribute`,
  `PSUseValidateNotNullOrEmpty`, `PSAvoidShorthandMandatory`,
  `PSAvoidExplicitParameterPosition`, `PSUseStandardCollectionOutput`,
  `PSAvoidAddMemberInLoop`, `PSUseBapAccessTokenEndpointSwitch`,
  `PSAvoidOrphanPSFFunctionInterruptCheck`,
  `PSUseCentralEnvironmentLookup`, `PSUseVariableNamingConvention`,
  `PSUseShouldProcessConvention`, `PSAvoidReturnValue`,
  `PSUseDeclaredOutputType`,
  `PSUseStandardParameterLayout`.
  Both alias rules are always on; the only way to permit an alias is a
  per-directory `ps1-lint.json` allowlist:
  `{"allowedCommandAliases": [], "allowedParameterAliases": ["PpacEnvId"]}`.
  Listed names (matched case-insensitively, exact spelling only) pass at
  declaration and use sites; everything else fails, including abbreviations
  of listed names. There is no off switch: to accept a new alias, add its
  name to the list in a reviewable diff — the red check on the PR is the
  signal, the list entry is the acceptance. Invalid configs fail with
  `PSAliasConfiguration` instead of silently passing. See the internal
  `Get-Ps1AliasConfiguration.ps1`.
  Current help-quality extensions: DESCRIPTION must not repeat SYNOPSIS, and
  parameters with code defaults must document them with a trailing
  `Default: ...` line as the last paragraph of the `.PARAMETER` section.
  `d365bap.tools/functions/ps1-lint.json` disables `PSAvoidParameterAliases`
  for the public functions: the `PpacEnvId` pipeline alias is an established
  repo-wide convention, so declaring it is not a violation there.
- `ps1-format/Run.ps1` — Invoke-Formatter with `internal/Ps1FormatSettings.psd1`
  plus UTF-8 BOM enforcement. Rewrites files and exits 1 when anything changed.
- `setup/Run.ps1` — installs PSScriptAnalyzer (CurrentUser) when missing.

## Wildcard parameters

`PSUseSupportsWildcards` keeps wildcard parameters consistent:

- A function parameter with a string default containing `*` must declare
  `[SupportsWildcards()]`. A default such as `'*'` or `'demo*'` means the parameter
  accepts a search pattern, so the attribute must advertise that to help and
  completion.
- A parameter with `[SupportsWildcards()]` must default to `*`. Wildcard
  parameters are always on, so a cmdlet never needs to test whether one was
  supplied.
- A `$PSBoundParameters.ContainsKey('Name')` or `$PSBoundParameters.Contains('Name')`
  check for a wildcard parameter is reported. Use `-Name` directly.

```powershell
param (
    [SupportsWildcards()]
    [string] $Name = "*"
)

$result | Where-Object Name -like $Name
```

Only `*` is checked; `?` and `[` are not used as wildcards in this codebase. The
rule reads the AST, so it ignores wildcard text inside strings and comments.
Non-string parameters, script-level parameters, and non-constant defaults are not
checked. The bound-parameter checks only apply to a literal parameter name in the
same function; a variable name or a nested function is not reported.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1WildcardRule.ps1
```

## Redundant parameter attributes

`PSAvoidRedundantParameterAttribute` fails two shapes that add nothing:

- `[Parameter()]` declared without arguments. Use it only when it carries
  information.
- Named arguments that restate the attribute default, such as
  `Mandatory = $false`, `ValueFromPipeline = $false`,
  `ValueFromPipelineByPropertyName = $false`,
  `ValueFromRemainingArguments = $false`, `HelpMessage = $null`,
  `ParameterSetName = '__AllParameterSets'`, and `Position = -2147483648`.

Defaults come from `ParameterAttribute` itself, so the rule follows the
platform. State only what changes the default. Other empty attributes such as
`[CmdletBinding()]` and `[SupportsWildcards()]` are allowed because the
attribute itself carries the meaning.

```powershell
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [Parameter(ParameterSetName = 'Excel')]
    [switch] $AsExcelOutput
)
```

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1EmptyAttributeRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ParameterArgumentRule.ps1
```

## Mandatory parameters

`PSUseValidateNotNullOrEmpty` fails a mandatory `string` or `string[]`
parameter without a default value unless it also declares
`[ValidateNotNullOrEmpty()]`. Mandatory parameters still accept an empty
string, so the validation attribute is what actually rejects it.

```powershell
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
)
```

A parameter with any default assignment is exempt, because the default supplies
the value when the caller omits it. Value types such as `switch` and `int` are
exempt because `[ValidateNotNullOrEmpty()]` has no effect on them.

`PSAvoidShorthandMandatory` bans the shorthand `[Parameter(Mandatory)]` and
requires the explicit `[Parameter(Mandatory = $true)]` form used throughout the
codebase.

`PSAvoidExplicitParameterPosition` bans the `Position` argument in
`[Parameter()]` for module functions and internal scripts. Parameters bind in
declaration order, so reorder them instead of numbering them.
`Get-PpacFinOpsAsset.ps1` is allowlisted because its parameter sets need fixed
slots; that is the only exception. Build scripts, the installer, and `*Tests.ps1`
files are not checked.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ParameterPositionRule.ps1
```

## Collection output

`PSUseStandardCollectionOutput` requires every public cmdlet with array output
to meet two contracts:

- A table format view for every `PSTypeName` it emits. The view can live in any
  file under `d365bap.tools/xml/formats/table`.
- A `[switch] $AsExcelOutput` parameter. Presence only; the export
  implementation is not validated.

Arrays of scalar values (strings, numbers, booleans, dates, GUIDs) are exempt
from both. A list view is optional and not checked.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1StandardOutputRule.ps1
```

## Access token endpoints

`PSUseBapAccessTokenEndpointSwitch` fails a module script that requests a known
audience through a literal `-ResourceUrl` value. Each known audience has a
dedicated switch on `Get-BapAccessToken`, so the audience stays defined once:

```powershell
# Fails
$secure = Get-BapAccessToken -ResourceUrl 'https://graph.microsoft.com/'

# Passes
$secure = Get-BapAccessToken -Graph
```

| Audience | Switch |
| --- | --- |
| Business Application Platform | `-Bap` |
| Power Platform API | `-PowerPlatform` |
| Power Platform admin API | `-PowerPlatformAdmin` |
| Microsoft Graph | `-Graph` |

Trailing slashes and case are ignored, so
`-ResourceUrl 'https://api.powerplatform.com/'` is the same violation as
`-ResourceUrl 'https://api.powerplatform.com'`. An explicit resource for
anything else stays legitimate, for example a Dataverse environment URL. The
rule reads the AST; variables, splats, and URLs with a path are not checked. It
only runs on changed files, so remaining call sites migrate as their cmdlets are
touched.

The regression check also compares the rule map with
`$script:BapAccessTokenEndpoints` in `Get-BapAccessToken.ps1`; adding an endpoint
in only one place fails the check.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1AccessTokenRule.ps1
```

## Parameter layout

`PSUseStandardParameterLayout` requires a consistent parameter declaration:

- A blank line before every parameter after the first, including its attributes.
  The first parameter stays directly under `param (`.
- `[Parameter()]` attributes first, then `[ValidateSet()]`, then the remaining
  attributes, then the type constraint and the parameter name.
- No blank line between those stack items. Multi-line attributes are fine; only
  the gaps between stack items are checked.
- The type constraint and parameter name on one line, with exactly one space
  between the closing `]` and `$`.

The space check applies to every parameter in the file, including scriptblock
parameters. The other checks apply to public functions only; build and internal
scripts use their own layouts.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ParameterLayoutRule.ps1
```

## Note properties

`PSAvoidAddMemberInLoop` fails a note property added inside an iteration
construct when the property is never read or written inside that loop. It
covers `foreach`, `for`, `while`, `do/while`, `do/until`, `ForEach-Object`, and
`.ForEach()`. Every property added inside a loop must be used inside that loop;
otherwise move it out and add it in the Select-PSFObject or Select-Object
projection after the loop:

```powershell
$resCol = $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Example' -Property `
    'id as ConnectionId',
    @{ Name = 'PpacEnvId'; Expression = { $routeEnvironmentId } },
    @{ Name = 'PpacEnvName'; Expression = { $routeEnvironmentName } }
```

Dynamic property names, non-variable targets, and other member types are not
checked. The rule reads and writes inside the loop as usage; a property used
only after all loops must be projected outside. The rule runs on module code and
the lint tooling under `build/ps1-lint`. Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1AddMemberRule.ps1
```

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1MandatoryRule.ps1
```

## Internal comments

`PSOnlyCommentBasedHelp` fails every comment that is not comment-based help. It
covers module functions and internal scripts as well as build scripts, so a
changed cmdlet replaces inline notes with help or with self-explanatory code.
Region markers are the only exception because they fold code rather than
document it:

```powershell
# Fails
$cache = 1 # fill the cache

# Passes
<#
    .SYNOPSIS
        Fills the cache.

    .EXAMPLE
        PS C:\> Get-Fixture

        Fills the cache.
#>
```

`#requires` statements and shebangs are ignored. Test files (`*Tests.ps1` and
everything under `d365bap.tools/tests`) and tepp files (`*.tepp.ps1` and
`internal/tepp`) are exempt. Build scripts are also exempt because they carry
operational comments; the rule targets module code. The rule runs on changed
files only, so the remaining comments are removed as their files are touched.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1CommentRule.ps1
```

## Environment lookups

`PSUseCentralEnvironmentLookup` requires module code to look environments up
through `Get-Environment`, which returns the cheapest shape the caller asks for:

| Shape | Cost on a live tenant | Call |
| --- | --- | --- |
| BAP environment | ~0.6 s | `Get-Environment -EnvironmentId $id` |
| Unified, no provisioning data | ~0.7 s | `Get-Environment -EnvironmentId $id -Unified` |
| Unified with provisioning data | ~2.3 s warm | `Get-Environment -EnvironmentId $id -Unified -VersionDetails` |

```powershell
# Fails
$envObj = Get-BapEnvironment -EnvironmentId $id | Select-Object -First 1
$envObj = Get-UnifiedEnvironment -EnvironmentId $id | Select-Object -First 1
$environment = Get-Environment -EnvironmentId $id
try { $envObj = Get-Environment -EnvironmentId $id } catch { }
if ($null -ne $envObj) { }
$envObj = Get-Environment -EnvironmentId $id
if (Test-PSFFunctionInterrupt) { return }

# Passes
$envObj = Get-Environment -EnvironmentId $id | Select-Object -First 1
$envObj = Get-Environment -EnvironmentId $id -Unified | Select-Object -First 1
$envObj = Get-Environment -EnvironmentId $id -Unified -VersionDetails | Select-Object -First 1
```

`Get-Environment` stops execution with an actionable message when no environment
matches. Callers assign it to a local variable named `$envObj` (the prefix is what
later analysis keys on), do not wrap it in `try`/`catch`, do not test the variable
for `$null`, and do not test `Test-PSFFunctionInterrupt` immediately after the
lookup. The variable is always set and the lookup never returns to the caller when
it fails.

The per-environment provisioning lookup is what makes the full shape expensive,
so only callers that read fields such as `PpacProvApp` should ask for it. The
rule reports `Get-UnifiedEnvironment -SkipVersionDetails` as `-Unified` and a
plain `Get-UnifiedEnvironment` as `-Unified -VersionDetails`.

`Get-BapEnvironment.ps1`, `Get-UnifiedEnvironment.ps1`, and `Get-Environment.ps1`
are exempt because they implement the lookup; test files and the tepp scripts are
exempt too. The rule runs on changed files only, so callers migrate as their files
are touched.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1EnvironmentLookupRule.ps1
```

## Variable naming

`PSUseVariableNamingConvention` keeps variable names readable as types and scopes:

| Variable | Prefix | Example |
| --- | --- | --- |
| Hashtable, ordered dictionary | `hash` | `$hashConfig = @{ Key = 'Value' }` |
| Collection, array, list | `col` | `$colAssets = @(...)` |
| Single object at the function root | `obj` | `$objPolicy = $colPolicies \| Select-Object -First 1` |
| `foreach` item | `item` | `foreach ($itemAsset in $colAssets) { }` |
| Any variable declared inside a loop | `tmp` | `$tmpName = $itemAsset.Name` |

```powershell
$colAssets = @(Get-Thing)
$hashConfig = @{ Key = 'Value' }
foreach ($itemAsset in $colAssets) {
    $tmpName = $itemAsset.Name
}
```

Inside a loop, `tmp` wins over the shape prefixes, so a collection or hashtable
declared in the loop body is still `$tmp*`.

The rule reads the AST. It recognizes `@(...)`, `@()`, array literals, hashtables,
`[ordered]`, `[hashtable]`, `[System.Collections.*]` constructors, `foreach`
sources, `[pscustomobject]`, `New-Object`, and pipelines ending in
`Select-Object -First 1`. It also reads the called module function's
`[OutputType()]` attribute. Strings, numbers, booleans, member access, parameters,
automatic variables, and scope-qualified variables are not checked. A
`Get-Environment` result keeps its `$envObj` name because the environment rule
owns that contract.

```powershell
function Get-Route {
    [OutputType([PSCustomObject])]
    param()
}

function Get-Routes {
    [OutputType('System.Object[]')]
    param()
}

$objRoute = Get-Route
$objFirst = Get-Routes | Select-Object -First 1
$colRoutes = Get-Routes
```

`Object[]` and collection types require `col`; hashtable and dictionary types
require `hash`; `PSCustomObject`, `PSObject`, and custom classes require `obj`;
scalar types such as `string`, `bool`, `int`, and `guid` are ignored.
`Select-Object -First 1` turns a collection result into `obj`; other `-First`
values keep the collection requirement. External cmdlet `[OutputType]` is not
used because it describes the element type, not whether the command emits one or
many items.

The rule runs on module code and build scripts under `build/`. Test files and
tepp scripts are exempt. It runs on changed files only, so the existing names
are reshaped as their files are touched.

## Declared output types

`PSUseDeclaredOutputType` requires every public and internal module function to
declare a non-empty `[OutputType()]`.

| Function outputs | Declaration |
| --- | --- |
| A single PSF object | `[OutputType('D365Bap.Tools.X')]` |
| A PSF collection | `[OutputType('D365Bap.Tools.X[]')]` |
| An anonymous property bag | `[OutputType([PSCustomObject])]` |
| A hashtable | `[OutputType([hashtable])]` |
| A scalar | `[OutputType([string])]`, `[OutputType([bool])]`, etc. |
| No output | `[OutputType([void])]` |

```powershell
function Get-Fixture {
    [OutputType('D365Bap.Tools.Example[]')]
    param()

    Get-Thing | Select-PSFObject -TypeName 'D365Bap.Tools.Example'
}
```

A function that uses `Select-PSFObject -TypeName` or `PSTypeName` must declare
that exact type. The `[]` suffix is allowed for collections. `System.Object`
alone is rejected as too broad, and `System.Object[]` alone is rejected because
it does not name the element type. `PSCustomObject` is allowed only when no
named PSF type is present. `[void]` cannot be mixed with other types.

The existing `PSUseStandardCollectionOutput` recognizes any OutputType ending in
`[]`, so `D365Bap.Tools.X[]` keeps the table-view and `AsExcelOutput` checks
working.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1OutputTypeRule.ps1
```

## ShouldProcess

`PSUseShouldProcessConvention` keeps a cmdlet's confirmation honest:

- A function that declares `[CmdletBinding(SupportsShouldProcess = $true)]` must call
  `ShouldProcess`. A call without the declaration is reported too.
- Only the two-argument form is allowed.
- The first argument must be the local variable `$shouldAffected`; the second must
  be the local variable `$shouldLabel`.
- `$shouldAffected` must describe the target with a name, display name, title, text
  or description. An id alone is not human friendly.
- `$shouldLabel` must be a string literal describing the action, not a bare id or a
  variable.
- `$shouldAffected` expands to at most 85 characters and `$shouldLabel` to at most
  125. Every variable or property counts as 36 characters; literal text counts as
  written.
- The two assignments sit on consecutive lines, followed by exactly one blank line
  and then the `if` statement.

```powershell
$shouldAffected = "$($envObj.EnvName) ($($envObj.EnvId))"
$shouldLabel = "Assign ACP $($policy[0].PolicyId) - $($policy[0].Name)"

if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }
```

The rule runs on module functions and internal scripts, changed files only.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1VariableNamingRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ShouldProcessRule.ps1
```

## Function interrupts

`PSAvoidOrphanPSFFunctionInterruptCheck` flags a `Test-PSFFunctionInterrupt` check in a
process block when nothing before it can interrupt the function:

```powershell
# Fails: no begin block, nothing has run
function Set-Fixture {
    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}

# Fails: the begin block only builds a hashtable
function Set-Fixture {
    begin {
        $hashConfig = @{ Key = 'Value' }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}

# Passes: a begin command may interrupt
function Set-Fixture {
    begin {
        $envObj = Get-Environment -EnvironmentId $EnvironmentId
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
    }
}

# Passes: the check follows the command that can stop
function Set-Fixture {
    process {
        $envObj = Get-Environment -EnvironmentId $EnvironmentId
        if (Test-PSFFunctionInterrupt) { return }
    }
}
```

Empty begin blocks and assignment-only begin blocks do not count. The rule does
not trace helper call graphs: any preceding command is treated as a possible
interrupt source, which avoids false positives when a begin block calls a helper
that uses `Stop-PSFFunction -StepsUpward`. Test files and tepp scripts are
exempt.

## Return values

`PSAvoidReturnValue` rejects `return <value>` in PowerShell code. `return`
exits the current scope; values are emitted by the pipeline. `return $x` is
shorthand for `$x; return`.

```powershell
# Fails
function Set-Fixture {
    return $value
}

# Passes: the value is the output, the function ends anyway
function Set-Fixture {
    $value
}

# Passes: emit the value, then use a bare return to exit early
function Set-Fixture {
    if ($done) {
        'finished'
        return
    }

    Get-Thing
}
```

Use a bare `return` to stop execution. `return $null` is reported; a bare
`return` is clearer. Class methods are exempt because PowerShell classes require
`return` for method output.

The rule checks module and build scripts; `*Tests.ps1`, `d365bap.tools/tests`,
and tepp files are exempt. It runs on changed files only.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1FunctionInterruptRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ReturnValueRule.ps1
```

## Example prose

`PSHelpExample` checks each `.EXAMPLE` independently:

- Keep code, exactly one blank separator, then prose without blank lines.
- Write standalone prose. References such as "Same as above", "as before",
  or "see the previous example" fail.
- An optional opening summary must be fewer than 125 characters.
- Explain each explicit parameter on its own new line starting with `It `.
  Both `It uses ...` and `It will use ...` pass. Each line must be 80
  characters or fewer, excluding indentation and comment markers.
- Name the parameter as `-ParameterName` on that line. An exact declared alias
  also counts. This makes coverage checkable without treating ordinary words
  such as "name" as parameter references. A summary does not satisfy coverage,
  and combining two parameters on one detail line fails.
- Explain omitted defaults on separate `It ...` lines too. Defaults come from
  code assignments and `.PARAMETER` prose such as `Default: ...`, "When omitted,
  ...", or "If not specified, ...". Documented built-in and tenant defaults
  count even when the signature has no default assignment.
- Omitted search defaults such as `*`, `demo*`, and documented wildcard or
  `-like` searches do not need a line. Explicit search parameters still do.
- Explicit values replace defaults for coverage. Common parameters such as
  `-WhatIf` need their own lines when specified. Parameters in other commands
  in a pipeline need lines too. Examples with splatting must spell out the
  parameters so coverage can be checked without executing the example.

The total explanation can exceed 124 characters. Only the optional summary
keeps the old limit. Existing `.PARAMETER` default documentation rules still
apply separately. The lint checks structure and parameter references; reviewers
still check that each explanation describes the command accurately.

### PR #225 as a worked example

The second example in [PR #225](https://github.com/d365collaborative/d365bap.tools/pull/225)
currently says `Same as above, but with the custom domain name "myudeenv".`
That passes the old separator and total-length checks. It fails the new rule
because it depends on another example and omits parameter and default lines.
Its standalone replacement is:

```powershell
.EXAMPLE
    PS C:\> New-UnifiedEnvironmentV2 -Type "UDE" -Name "MyUdeEnv" -Location "europe" -CustomDomainName "myudeenv"

    Creates a Unified developer environment with a custom domain.
    It will create a developer environment with -Type UDE.
    It will display -Name MyUdeEnv in the admin center.
    It will deploy to -Location europe.
    It will use -CustomDomainName myudeenv.
    It will use -Template D365_DeveloperEdition by default.
    It will use the tenant default for -Language.
    It will use the tenant default for -Currency.
    It will wait 60 seconds with the default -PostProvisionDelaySeconds.
    It will allow 60 minutes with the default -ReadyStateTimeoutMinutes.
```

The third example also needs separate lines for `-Version` and `-WhatIf`.
Its `-WhatIf` line must explain that the command previews the request rather
than creating an environment. Defaults describe the values in that preview.

Run the regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ExampleHelp.ps1
```
