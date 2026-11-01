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

`PSUseSupportsWildcards` fails a function parameter that declares a string
default containing `*` without a `[SupportsWildcards()]` attribute. A default
such as `'*'` means the parameter accepts a search pattern, so the attribute
must advertise that to help and completion. Only `*` is checked; `?` and `[`
are not used as wildcards in this codebase.

```powershell
param (
    [SupportsWildcards()]
    [string] $Name = "*"
)
```

The rule reads the AST, so it ignores wildcard text inside strings and
comments. Non-string parameters, script-level parameters, and non-constant
defaults are not checked.

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
only after all loops must be projected outside. Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1AddMemberRule.ps1
```

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1MandatoryRule.ps1
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
