# ps1-lint (vendored)

PowerShell lint hook scripts for `prek.toml`. They started as a copy of the
PS1 hooks from an internal-only module and are maintained in this repo from
here on — no submodule, no sync back. Rule changes happen here via normal PRs.

What runs on PowerShell files:
- `lint/Run.ps1` — the hook entry point used by `prek.toml` and CI. It formats
  and analyzes each bounded batch in one `pwsh` process
  (`internal/Invoke-Ps1LintBatch.ps1`), so a lint run pays one process start and
  one PSScriptAnalyzer import instead of one per hook. `-CheckOnly` (or
  `PS1_LINT_CHECK_ONLY=1`) never writes a file and still reports formatting
  drift. See [One batch process](#one-batch-process).
- `psscriptanalyzer/Run.ps1` — the single-phase analyzer entry point
  (`internal/Invoke-Ps1Analysis.ps1`) runs native PSScriptAnalyzer plus the
  repository rules below. It stays available for targeted analysis (the
  dependency report in `build/Invoke-Ps1LintScope.ps1`) and for the regression
  tests. Parser errors are collected separately and always
  fail, because PSScriptAnalyzer reports them as `ParseError` rather than
  `Error`. Module functions fail on errors and warnings; build scripts and
  other tooling keep the historical error-only gate. `.psm1` and `.psd1` files
  receive syntax and built-in rule coverage only; public-function conventions
  do not apply to them. PSScriptAnalyzer rules already owned elsewhere are
  excluded: `PSAvoidUsingCmdletAliases` (the alias rules below) and
  `PSAvoidTrailingWhitespace` (the format hook). `PSShouldProcess` is filtered
  only for module function files, where `PSUseShouldProcessConvention` replaces
  it; build scripts keep the built-in check.
  Repository rules: `PSOnlyCommentBasedHelp`,
  `PSHelpSynopsis/Description/Parameter/Notes/Example`,
  `PSAvoidCommandAliases` / `PSAvoidParameterAliases`,
  `PSUseSupportsWildcards`, `PSAvoidRedundantParameterAttribute`,
  `PSUseValidateNotNullOrEmpty`, `PSAvoidShorthandMandatory`,
  `PSAvoidExplicitParameterPosition`, `PSUseStandardCollectionOutput`,
  `PSAvoidAddMemberInLoop`, `PSUseBapAccessTokenEndpointSwitch`,
  `PSAvoidOrphanPSFFunctionInterruptCheck`,
  `PSUseCentralEnvironmentLookup`, `PSUseVariableNamingConvention`,
  `PSUseShouldProcessConvention`, `PSAvoidReturnValue`,
  `PSUseDeclaredOutputType`, `PSAvoidObjectArrayCast`,
  `PSUseValidationAttributeOnMandatory`,
  `PSUseWildcardParameterAsFilter`,
  `PSUseOrderedPSCustomObject`,
  `PSAvoidOutNull`,
  `PSUseStandardExcelExport`,
  `PSAvoidLoopAppend`, `PSAvoidNotEqualNull`, `PSUsePipelineContinuationBreak`,
  `PSUseOneParameterPerLine`, `PSUseDirectValueInStringCheck`,
  `PSUseVariableForHeaders`, `PSAvoidSplattingForModuleCommands`,
  `PSUseEmptyLineAfterContinuation`, `PSUseDirectParameterCheck`,
  `PSUseReturnAfterStopPSFFunction`,
  `PSUseOneComplexArrayElementPerLine`,
  `PSUseExplicitSelectObjectProperty`,
  `PSUseMultilineSelectObjectProperty`,
  `PSUseMultilineIfExpression`,
  `PSUseMultilineIfCondition`, `PSUseTernaryInObjectInitialization`,
  `PSUseCentralApiVersion`, `PSUseFormattedUrl`,
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
  `d365bap.tools/functions/ps1-lint.json` lists `PpacEnvId` in
  `allowedParameterAliases`: the pipeline alias is an established repo-wide
  convention, so declaring and using it is not a violation there.
- `ps1-format/Run.ps1` — the single-phase formatter entry point:
  Invoke-Formatter with `internal/Ps1FormatSettings.psd1` plus UTF-8 BOM
  enforcement. Rewrites files and exits 1 when anything changed or a file could
  not be formatted. It stays available for formatting one file or a directory
  directly. A formatting failure does not disappear as a warning when the file
  content stays unchanged.
- `setup/Run.ps1` — installs the pinned PSScriptAnalyzer 1.25.0 (CurrentUser)
  when that version is missing.
- The local analysis result cache reuses an unchanged file's result on the next
  local run. CI never uses it. See [Local analysis result cache](#local-analysis-result-cache).

### One batch process

`lint/Run.ps1` calls `internal/Invoke-Ps1LintBatch.ps1`, which does both phases
in the same process:

1. Format each `.ps1` file in the current chunk and write it unless
   `-CheckOnly` is set. `.psm1` and `.psd1` files are not formatted, as before.
2. Analyze every file in that chunk. `.ps1` files are analyzed from the
   formatted text, not from the bytes that were on disk before formatting, so
   write mode and check-only mode report the same diagnostics. `.psm1` and
   `.psd1` files are analyzed from their path because the formatter never
   touches them.

`pass_filenames=128` in `prek.toml` bounds the process. Inside it, files are
processed in chunks of 32 (`-BatchSize`) so formatted text for a large tree is
not held in memory at once. Each file has its own `try/catch`: a read-only file,
a formatter failure, or a rule exception is reported and the rest of the batch
continues.

Exit codes keep the old two-hook contract: the hook exits 1 when formatting
changed a file, would change a file in check-only mode, or failed; it also exits
1 when analysis has a fatal diagnostic. Otherwise it exits 0. Running the hook
twice leaves the tree unchanged after the first run, and `-CheckOnly` leaves it
unchanged on every run.

On the #334 baseline a 64-file batch started two fresh `pwsh` processes and
imported PSScriptAnalyzer twice. The combined hook starts and imports once. The
repository index is still built once per process, and PSScriptAnalyzer's
helper processes are unchanged because the analyzed file count is unchanged.

CI sets `PS1_LINT_CHECK_ONLY=1` for the `ps1-lint` step, so the same hook and
glob filtering apply but nothing is written to the runner checkout.

### One pinned analyzer runtime

`internal/Ps1AnalyzerSettings.psd1` owns the single `PSScriptAnalyzerVersion`
pin (1.25.0). `internal/Import-Ps1Analyzer.ps1` is the only import path:

- `lint`, `ps1-format`, and `psscriptanalyzer` all import through it, so
  formatting and analysis always run on the same module build.
- It removes any other loaded version, imports the pinned one with
  `-RequiredVersion`, and throws unless the pinned version is the only one
  loaded. A newer version that happens to be installed cannot win.
- `setup/Run.ps1` and the CI lint job install that same pin
  (`build/ModuleCacheRequirements.json`, `lint` set). A regression check asserts
  the settings pin and the cache pins match.

`build/Test-Ps1LintCorrectness.ps1` proves the pin: it installs a decoy
PSScriptAnalyzer 99.0.0 that throws on import, runs both hooks with the decoy
first on `PSModulePath`, and requires byte-identical formatting and identical
analysis to a run without it. Because CI and local runs execute the same hook
scripts, that check covers both.

### Rule plumbing

Each rule function receives the analysis hashtable from `Get-Ps1Analysis`
(`internal/Get-Ps1Analysis.ps1`). The hashtable carries the parsed `Ast`,
`Tokens`, and `ParseErrors`, plus `CommentGroups`, `HelpSections`, and the
values the shared helpers use. Rules keep their own checks; the repeated
plumbing lives in four helpers:

- `Test-Ps1RuleScope -Analysis $Analysis -Scope <name>` decides whether a
  rule applies to the file. The scope table names the supported scopes:
  `ModuleSource` (module code, no tests or tepp), `ModuleSourceWithTepp`,
  `ModuleOrBuild`, `ModuleOrLintTooling`, `PublicFunction`, `FunctionFile`,
  `OutputTypeFile`, `RepositoryScript`, and `Documentation`. A rule calls it
  once and returns when it is false; no rule normalizes a path on its own.
- `Get-Ps1AstNode -Analysis $Analysis -Type <name>[,<name>] [-Root <node>]`
  returns the nodes of one or more AST types in document order. The result is
  collected once per analysis, search root, and type set, so every rule that
  asks the same question reuses the same collection. Pass a root node to
  search inside a function body. Do not mutate a returned collection.
- `Get-Ps1TokenNode -Analysis $Analysis -Kind <TokenKind>` does the same for
  a token kind such as `Pipe`, `LineContinuation`, or `Format`.
- `New-Ps1Diagnostic $Path $RuleName $Message $Extent` is the only
  diagnostic shape. It always reports `Error` severity and takes the line and
  column from the extent. Pass `$null` for the extent and then the line and
  column when the position is not an extent.

Rule logic stays in the rule file. Adding a rule means writing its checks,
registering it in `Get-Ps1DiagnosticRule`, and adding a
`build/Test-Ps1*Rule.ps1` suite (registered in
`build/Test-Ps1RuleSuites.ps1`).

`Invoke-Ps1Analysis -SkipCustomRules` is the built-in-only mode the full-module
scans use. It passes the same flag to `Get-Ps1Analysis`, which then builds only
what the built-in analyzer and the failure policy read: the parse result,
tokens, parse errors, the scope flags, and the node and token caches. Comment
groups and help sections serve repository rules only, and each comment group
parses the whole file again, so built-in-only scans do not build them and the
analysis carries no `CommentGroups` or `HelpSections` key.
`Test-Ps1LintCorrectness.ps1` pins both halves: the entry point asks for the
mode, and the keys are absent. Diagnostics, parse errors, and the severity and
high-signal failure rules do not change.

### Repository metadata index

Rules that need repository facts share one index per module root and analysis
worker (`Get-Ps1RepositoryIndex` in `internal/Get-Ps1Analysis.ps1`). The module
files are read once, and the index records:

- `Commands` - every function name defined by the module, including nested
  helpers and the files under `internal/sdk`. `PSAvoidSplattingForModuleCommands`
  uses it to tell a module command from a system command.
- `Functions` - parameter and alias metadata for the function files under
  `functions/`, `internal/functions/`, and `internal/scripts/`. The alias rules
  resolve calls against it.
- `OutputTypes` - the declared `[OutputType()]` shape of those functions.
  Variable naming uses it to choose `hash`, `col`, or `obj`.

The index is built the first time a rule asks for it and reused by every later
rule and file in that process. `prek.toml` batches the combined hook with
`pass_filenames=128`, so a full repository scan pays the build once per batch
instead of once per file, and formatting no longer starts a second process that
would never use the index. Each process starts a new worker, so the next run
always sees edits. A running worker does not rebuild the index;
repository facts must not be cached at script scope, because that would keep
stale results for the rest of the process. `Test-Ps1LintCorrectness.ps1` checks
both halves of that contract with the worker's `RepositoryIndexBuilds` counter.

### Local analysis result cache

Repeated local runs reuse the analysis result of an unchanged file.
`internal/Get-Ps1AnalysisCache.ps1` stores one result per file and kind under
`.ps1-lint-cache/` at the repository root, which `.gitignore` keeps out of git.

- `builtin` entries hold the PSScriptAnalyzer diagnostics. The key is the
  analyzed text (the formatted text in a lint batch, the file bytes otherwise),
  the analyzer settings file content, the pinned PSScriptAnalyzer version, and
  the file path.
- `custom` entries hold the repository rule diagnostics. The key adds a
  fingerprint of the repository metadata the rules read: function parameter
  names and aliases, declared output types, and command names from the shared
  index, plus the `ps1-lint.json` allowlist that applies to the file, plus a
  session-level fingerprint of the rule implementation itself (every
  `Get-Ps1*Diagnostic.ps1` and the shared helpers it calls). Editing one
  function's body leaves another file's custom entry valid; changing a
  parameter or an output type anywhere in the module invalidates it, and so
  does editing a rule under `build/ps1-lint/internal`. The rule-code
  fingerprint does not touch built-in entries, so a rule edit still reuses the
  PSScriptAnalyzer result.
- A complete hit skips the parse, the analyzer, and the rules. A parse failure
  is stored with the entry, so it reproduces the parse-only result.
- Every read revalidates the schema and the stored key. A missing, damaged, or
  mismatched entry is a miss, and any cache error disables the cache for the
  rest of the process instead of failing the run.
- Cache entries never expire; the folder is reset once the recorded write count
  passes 20000, so it cannot grow without bound.

The cache is local only. It stays off when `CI` or `TF_BUILD` is set, and
`PS1_LINT_CACHE=off` disables it explicitly; `PS1_LINT_CACHE=<folder>` points it
elsewhere. CI therefore runs exactly the uncached path. A local run prints one
line with the reuse count:

```text
  analysis cache: reused 941 of 941 result(s) (100%), wrote 0 entry(ies).
```

`build/Test-Ps1AnalysisCache.ps1` covers the reuse, the invalidation inputs, the
damaged-entry fallback, and the CI and off switches.

### High-signal built-in warnings

These existing PSScriptAnalyzer rules are fatal for module and build code even
where ordinary warnings keep the historical error-only gate:

- `PSAvoidAssignmentToAutomaticVariable`
- `PSAvoidUsingEmptyCatchBlock`
- `PSPossibleIncorrectComparisonWithNull`
- `PSAvoidUsingInvokeExpression`
- `PSUseProcessBlockForPipelineCommand`

Tepp files, tests, and the root installer stay outside this gate until their
existing debt is addressed. The rules are still reported there; they just do
not fail the hook.

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

`PSUseValidateNotNullOrEmpty` requires a mandatory `string` or `string[]`
parameter without a default value to declare `[ValidateNotNullOrEmpty()]`.
PowerShell already rejects null and empty values when it binds a mandatory
string parameter; the attribute is a repository convention that states the
contract in the signature and keeps it visible to reviewers.

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

The rule is public-only by contract. `-AsExcelOutput` is how a public cmdlet
offers a spreadsheet export; an internal helper never declares that switch, so
requiring it there would create false positives rather than coverage.

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
parameters. The other checks apply to public functions and one-function files
under `internal/functions`; other internal scripts and build scripts use their
own layouts.

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

The rule matches one function per file by filename. The multi-function files
under `internal/sdk` (`runtime`, `provisioning`, and the two preloads, 21
functions together) are therefore not checked; widening the guard would need a
different function lookup, so the gap is recorded rather than papered over.

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

# Fails: the Stop guard returns before the check
function Set-Fixture {
    process {
        $route = Get-Route
        if ($null -eq $route) {
            Stop-PSFFunction -Message 'not found'
            return
        }

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

Empty begin blocks and assignment-only begin blocks do not count. A
`Test-PSFFunctionInterrupt` check immediately after a same-scope
`Stop-PSFFunction` guard is also reported when the guard returns, uses
`-StepsUpward`, or uses `-EnableException $true`; that guard cannot reach the
check. A helper call in the guard and a `Stop-PSFFunction` in `begin` remain
valid sources, as does a direct stop that lets the function continue. The rule
does not trace helper call graphs, which avoids false positives when a helper
uses `Stop-PSFFunction -StepsUpward`. Test files and tepp scripts are exempt.

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

Use a bare `return` to stop execution. A bare `return` emits nothing, while
`return $null` emits one null item into the pipeline; replacing one with the
other can change observable output. The rule rejects every `return <value>`;
when the null is intended output, emit `$null` explicitly instead of returning
it. Class methods are exempt because PowerShell classes require `return` for
method output.

The rule checks module and build scripts; `*Tests.ps1`, `d365bap.tools/tests`,
and tepp files are exempt. It runs on changed files only.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1FunctionInterruptRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ReturnValueRule.ps1
```

## Object array casts

`PSAvoidObjectArrayCast` rejects a cast to `[object[]]`. `@()` already returns
an array; the element type adds nothing and hides the actual value shape:

```powershell
# Fails
$colResult = [object[]]@($response.value)
[object[]] $colResult = @()

# Passes
$colResult = @($response.value)
```

`[OutputType([object[]])]` is exempt because it declares the output contract,
and a parameter type is a type constraint rather than a cast. Scope: module code
(public and internal); build scripts, test files, and tepp fixtures are out of
scope.

## Validation attribute on mandatory parameters

`PSUseValidationAttributeOnMandatory` is the converse of
`PSUseValidateNotNullOrEmpty`: `[ValidateNotNullOrEmpty()]` is legal only on a
mandatory parameter or one with a default.

```powershell
# Fails: optional and no default, so the attribute can never reject anything
param (
    [ValidateNotNullOrEmpty()]
    [string] $Name
)

# Passes
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
)

# Passes: the default supplies the value
param (
    [ValidateNotNullOrEmpty()]
    [string] $Name = 'fixture'
)
```

Mandatory in any parameter set counts, because every `[Parameter()]` attribute
on the parameter is inspected. Any default assignment, including `= ''` and
`= $null`, is exempt. A parameter that needs an "optional but not empty"
contract uses `[ValidateScript()]` instead; this rule does not touch that
attribute. Script `param()` blocks are not judged; the rule runs on function
definitions in `functions/` and `internal/functions/`, so build scripts are out
of scope.

## Wildcard filters

`PSUseWildcardParameterAsFilter` treats a wildcard parameter's value as a
filter, never as a mode switch. Comparing it with the literal `'*'` is
reported:

```powershell
# Fails
param (
    [SupportsWildcards()]
    [string] $Name = '*'
)

if ($Name -ne '*') {
    'filtered'
}

# Passes: the filter is passed to the comparison
$result | Where-Object Name -like $Name
```

A parameter is wildcard-shaped when it declares `[SupportsWildcards()]` or has
a string default containing `*`. Only `-eq`, `-ne`, `-ceq`, and `-cne` against
the exact literal `'*'` are reported; `-like`, other literals, and member
expressions such as `$_.Name -eq '*'` are left alone. A local assignment to
the same name shadows the parameter and is skipped, as is a scope-qualified
variable. The rule runs on `functions/` and `internal/functions/`; generated
SDK wrappers and `build/` are out of scope. `PSUseSupportsWildcards` owns the
attribute and default contract; this rule only owns the value comparison.

## Ordered PSCustomObject

`PSUseOrderedPSCustomObject` requires a `[pscustomobject]` built from a
hashtable literal to go through `[ordered]`, so the property order is explicit
instead of a hashtable implementation detail:

```powershell
# Fails
$objResult = [pscustomobject]@{
    Name = 'fixture'
}

# Passes
$objResult = [pscustomobject][ordered]@{
    Name = 'fixture'
}
```

The rule follows parentheses to the literal, so `[pscustomobject](@{ ... })` is
reported and `[pscustomobject]([ordered]@{ ... })` passes. A variable child
such as `[pscustomobject]$hashSource` cannot be ordered statically and is
ignored. It runs on module code (public and internal); build scripts, test
files, and tepp fixtures are out of scope.

## Output discards

`PSAvoidOutNull` rejects, in module code and the lint tooling, the two discard
forms that do not redirect output to `$null`: `Out-Null` and assigning a command
or expression to `$null`. A discard redirects to `$null`, which is the faster,
allocation-free form and keeps the discarded value visible in review:

```powershell
# Fails
[int]::TryParse($Value, [ref]$IsInt) | Out-Null
Out-Null -InputObject (Get-Thing)
$null = Invoke-RestMethod -Method Post -Uri $uri
$null = $list.Add($item)
$null = $_.Exception.Message
$null = 5
$null = $commandName, $parameterName
$null = if ($true) { Get-Thing }

# Passes
[int]::TryParse($Value, [ref]$IsInt) > $null
Get-Thing > $null
Invoke-RestMethod -Method Post -Uri $uri > $null
$list.Add($item) > $null
$_.Exception.Message > $null
5 > $null
$(if ($true) { Get-Thing }) > $null
```

The `Out-Null` check matches the command name, so
`Microsoft.PowerShell.Core\Out-Null` and `out-null` are reported too. A file
that defines `function Out-Null` or `Set-Alias Out-Null` skips that check
because the local name may have different behavior; the `$null` assignment check
still runs.

The `$null` assignment check reports every assignment to `$null`. The message
names the command when the right side contains one; a keyword statement is
reported with the `$(...)` redirect form. A variable named `$null` with a scope
qualifier is not the automatic variable and is not checked. Test files and tepp
fixtures are exempt. Existing call sites in the lint tooling migrate as those
files are touched.

## Splatting module commands

`PSAvoidSplattingForModuleCommands` rejects a splat when the called command is a
function defined in the module, public or internal. The call site must name each
parameter so a reviewer can see what is passed:

```powershell
# Fails
$params = @{
    EnvironmentId = $EnvironmentId
    Asset         = $Asset
}
$colAssets = Get-PpacFinOpsAsset @params

# Passes
$colAssets = Get-PpacFinOpsAsset -EnvironmentId $EnvironmentId -Asset $Asset
```

Splatting a system command stays allowed, because its parameters are not part
of this module's contract:

```powershell
$request = @{
    Method = 'Post'
    Uri    = $uri
}
Invoke-RestMethod @request
```

The rule resolves the called command against every function defined in the
module, including nested helpers and functions under `internal/`. It reads the
shared repository index, so the module is scanned once per run rather than once
per file. A dynamic command name, a command qualified with another module, and
`Microsoft.PowerShell.*` commands are not checked. Test files and tepp fixtures
are exempt.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ModuleSplattingRule.ps1
```

## Excel export blocks

`PSUseStandardExcelExport` requires every public cmdlet that declares
`[switch] $AsExcelOutput` to end with the canonical export block. The switch
must do something, name its worksheet after the cmdlet, and return:

```powershell
if ($AsExcelOutput) {
    $resCol | Export-Excel -WorksheetName 'Get-Fixture'
    return
}
```

Reported shapes: no `if ($AsExcelOutput)` block at all, an `elseif`/`else`
branch on that block, a result-count guard inside it (`if ($resCol) { ... }`),
a worksheet name that is not the cmdlet name, and a block that does not end
with a bare `return`. Additional `Export-Excel` parameters after
`-WorksheetName` are allowed.

`Get-UdeConnection` is exempt from the name check because its worksheet is
`UdeConnection`; the rest of the shape still applies to it. A non-literal
worksheet name such as `-WorksheetName $name` cannot be verified and is
ignored. A wrapper that only forwards `-AsExcelOutput` to another command has
no local block and is exempt. The rule runs on public cmdlets under
`d365bap.tools/functions`; internal helpers are out of scope.

## Loop appends

`PSAvoidLoopAppend` rejects a `foreach` whose only statement adds the loop
variable to another collection. The loop is a copy; assign the source or use
`AddRange`:

```powershell
# Fails
foreach ($item in $colSource) {
    $colTarget.Add($item)
}

# Passes
$colTarget.AddRange($colSource)

# Passes: the loop body does more than copy
foreach ($item in $colSource) {
    $colTarget.Add($item.Projection)
}
```

The body must be exactly one statement, and that statement must be
`<collection>.Add($<loop variable>)` with the canonical `Add` spelling. A
property argument, a second statement, an `if`, or a different argument name is
not the shape and is ignored. A set-building loop still reports; `UnionWith` is
the replacement. `ForEach-Object` and `.ForEach()` are not covered, because the
set-construction pipelines that use them build a union rather than a copy.
Scope: module code (public and internal); build scripts, test files, and tepp
fixtures are out of scope.

## One parameter per line

`PSUseOneParameterPerLine` requires a command with more than one parameter to
put each parameter on its own line. The first parameter may stay on the command
line or move to the first continuation line.

```powershell
# Fails: two parameters on one line
Get-Thing -First 1 -Second 2

# Fails: two parameters on the first line
Get-Thing -First 1 -Second 2 `
    -Third 3

# Fails: two parameters on a continuation line
Get-Thing -First 1 `
    -Second 2 -Third 3

# Fails: all parameters on the first continuation line
Get-Thing `
    -First 1 -Second 2

# Passes: first parameter on the command line
Get-Thing -First 1 `
    -Second 2 `
    -Third 3

# Passes: first parameter on the first continuation line
Get-Thing `
    -First 1 `
    -Second 2
```

A command with zero or one parameter is not reported. Backticks are allowed;
the rule checks parameter placement, not the continuation itself. A format
expression can put the operator on a new line:

```powershell
$uri = 'https://api.powerplatform.com/authorization/roleAssignments?api-version={0}' `
    -f $script:BapApiVersions.PowerPlatform
```

A backtick inside a string, here-string, or comment is not a continuation and
stays clean. Test files, tepp fixtures, and the rest of `build/` are out of
scope. The rule runs on changed files only, so the existing multi-parameter
lines migrate as their files are touched.

## Headers variables

`PSUseVariableForHeaders` requires the `-Headers` argument to be a variable or
another expression, never an inline hashtable. The inline form puts the
hashtable body next to the command parameters, so the end of the hashtable is
hard to see in a multi-line call:

```powershell
# Fails
$created = Invoke-RestMethod -Method Post `
    -Uri $uri `
    -Headers @{
    Authorization = "Bearer $tokenValue"
    Accept        = 'application/json'
} `
    -Body $body `
    -ErrorAction Stop

# Passes
$hashHeaders = @{
    Authorization = "Bearer $tokenValue"
    Accept        = 'application/json'
}

$created = Invoke-RestMethod -Method Post `
    -Uri $uri `
    -Headers $hashHeaders `
    -Body $body `
    -ErrorAction Stop
```

A parenthesized hashtable and an `[ordered]` cast are reported too. A variable,
a member expression, and a command that returns headers pass. The rule matches
the `-Headers` parameter name on any command. A splat is not resolved. Test
files, tepp fixtures, and `build/` scripts are exempt. The rule runs on module
code (public and internal).

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1HeadersVariableRule.ps1
```

## One complex array element per line

`PSUseOneComplexArrayElementPerLine` requires an array with more than one
hashtable or scriptblock element to start each complex element on its own line.
Simple strings and numbers may share a line. The rule accepts any split that
keeps the complex elements apart:

```powershell
# Fails
$colPolicies = @($colPolicies | Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, @{ Expression = { $_.name } }, @{ Expression = { $_.id } })

# Passes: trailing comma
$colPolicies = @($colPolicies |
    Sort-Object -Property @{ Expression = { -not $_.IsEffective } },
    @{ Expression = { $_.name } },
    @{ Expression = { $_.id } })

# Passes: array variable
$colSort = @(
    @{ Expression = { -not $_.IsEffective } }
    @{ Expression = { $_.name } }
    @{ Expression = { $_.id } }
)
$colPolicies = @($colPolicies | Sort-Object -Property $colSort)

# Passes: simple property names after the one expression
$colPolicies = @($colPolicies |
    Sort-Object -Property @{ Expression = { -not $_.IsEffective } }, 'name', 'id')
```

A one-line `@( ... )` subexpression that contains a hashtable or scriptblock is
reported too, so the element moves onto its own line inside the array:

```powershell
# Fails
$tmpConnectorManagement = @($item.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }) | Select-Object -First 1

# Passes
$tmpConnectorManagement = @(
    $item.RuleSets | Where-Object { "$($_.id)" -eq 'ConnectorManagement' }
) | Select-Object -First 1

# Passes: no complex element
$objItem = @($items | Select-Object -First 1)
```

A `[pscustomobject]@{ ... }` element counts as complex. A single complex element
may stay on the command line. Test files, tepp fixtures, and `build/` scripts are
exempt. The rule runs on module code (public and internal).

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ComplexArrayElementRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1SelectObjectPropertyRule.ps1
```

## Select-Object projections

`PSUseExplicitSelectObjectProperty` requires `Select-Object` to name `-Property`
when its positional property list contains a calculated property:

```powershell
# Fails
$item | Select-Object *, @{ Name = 'Kind'; Expression = { $kind } }

# Passes
$item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }
```

Simple property names, `-First`, `-ExpandProperty`, and a splat stay clean.
Test files, tepp fixtures, and `build/` scripts are exempt. The rule runs on
module code (public and internal).

## Multiline Select-Object properties

`PSUseMultilineSelectObjectProperty` requires a calculated property on a
`Select-Object` property list to start on its own line. A list with one
calculated property and another element on the same line is reported:

```powershell
# Fails: simple name and calculated property on one line
$item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }

# Fails: two calculated properties on one line
$item | Select-Object -Property *, @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }

# Fails: the second calculated property shares the first line
$item | Select-Object -Property *,
    @{ Name = 'Kind'; Expression = { $kind } }, @{ Name = 'Source'; Expression = { $source } }

# Passes
$item | Select-Object -Property *,
    @{ Name = 'Kind'; Expression = { $kind } },
    @{ Name = 'Source'; Expression = { $source } }

# Passes: the calculated property starts on the next line
$item | Select-Object -Property *
, @{ Name = 'Kind'; Expression = { $kind } }

# Passes: one calculated property
$item | Select-Object -Property @{ Name = 'Kind'; Expression = { $kind } }

# Passes: one calculated property on a continuation line
$item | Select-Object `
    -Property @{ Name = 'Kind'; Expression = { $kind } }
```

A single calculated property may share the line with `-Property`. Simple
property names, a splat, and a parameter argument such as `-ExpandProperty Name`
are not checked. Test files, tepp fixtures, and `build/` scripts are exempt. The
rule runs on module code (public and internal).

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1MultilineSelectObjectPropertyRule.ps1
```

## Multiline if expressions

`PSUseMultilineIfExpression` requires an `if`/`else` used as an assignment value
to put each branch on its own lines. The rule covers variable and property
assignments:

```powershell
# Fails
$fullId = if ($itemConnector -like '/providers/*') { $itemConnector } else { "/providers/Microsoft.PowerApps/apis/$itemConnector" }

# Passes: multiline if expression
$fullId = if ($itemConnector -like '/providers/*') {
    $itemConnector
}
else {
    "/providers/Microsoft.PowerApps/apis/$itemConnector"
}

# Passes: declared variable
$fullId = $null
if ($itemConnector -like '/providers/*') {
    $fullId = $itemConnector
}
else {
    $fullId = "/providers/Microsoft.PowerApps/apis/$itemConnector"
}

# Passes: ternary
$fullId = $itemConnector -like '/providers/*' ? $itemConnector : "/providers/Microsoft.PowerApps/apis/$itemConnector"
```

The `{` and `}` of each branch and the `else` keyword each start on their own
line. An `if` expression without an `else` is not reported. A plain `if`
statement is not an assignment and is not reported. An `if` expression used as
an object initializer value belongs to `PSUseTernaryInObjectInitialization`.
Test files, tepp fixtures, and `build/` scripts are exempt. The rule runs on
module code (public and internal).

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1MultilineIfExpressionRule.ps1
```

## Ternary in object initializers

`PSUseTernaryInObjectInitialization` requires an `if`/`else` used as a hashtable
value to be a ternary operator instead. A multiline `if` block inside a
hashtable breaks the property layout; the ternary keeps one value on one line:

```powershell
# Fails
$hashRuleSet = [ordered]@{
    id      = 'ConnectorManagement'
    version = if ([string]::IsNullOrWhiteSpace("$($objRuleSet.version)")) { '1.0' } else { $objRuleSet.version }
    inputs  = [ordered]@{ AllowedConnectorList = @($colAllowed) }
}

# Fails: a multiline branch does not fix the object layout
$hashRuleSet = [ordered]@{
    id      = 'ConnectorManagement'
    version = if ([string]::IsNullOrWhiteSpace("$($objRuleSet.version)")) {
        '1.0'
    }
    else {
        $objRuleSet.version
    }
    inputs  = [ordered]@{ AllowedConnectorList = @($colAllowed) }
}

# Passes
$hashRuleSet = [ordered]@{
    id      = 'ConnectorManagement'
    version = [string]::IsNullOrWhiteSpace("$($objRuleSet.version")) ? '1.0' : $objRuleSet.version
    inputs  = [ordered]@{ AllowedConnectorList = @($colAllowed) }
}

# Passes: an if without an else has no ternary equivalent
$hashRuleSet = @{
    version = if ($Version) { $Version.ToString() }
}
```

The rule covers every hashtable literal, including `[ordered]@{}` and
`[pscustomobject]@{}` values and nested hashtables. Only an `if` with an `else`
is reported. Property assignments are not object initializers and stay with
`PSUseMultilineIfExpression`. Test files, tepp fixtures, and `build/` scripts
are exempt.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1TernaryInObjectInitializationRule.ps1
```

## Multiline if conditions and Where-Object predicates

`PSUseMultilineIfCondition` requires every test in a compound `if`, `elseif`,
or `Where-Object` predicate to sit in parentheses on its own line, with `-and`
or `-or` leftmost on the continuation line:

```powershell
# Fails: two tests on one line
if (-Not ($null -eq $objGroup) -and -not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)")) {
    $groupLabel = $objGroup.DisplayName
}

# Fails: the operator ends the line instead of starting it
if ((-Not ($null -eq $objGroup)) -and
    (-not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)"))) {
    $groupLabel = $objGroup.DisplayName
}

# Fails: the tests are not parenthesized
if (-Not ($null -eq $objGroup) `
        -and -not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)")) {
    $groupLabel = $objGroup.DisplayName
}

# Passes: two tests
if ((-Not ($null -eq $objGroup)) `
        -and (-not [string]::IsNullOrWhiteSpace("$($objGroup.DisplayName)"))) {
    $groupLabel = $objGroup.DisplayName
}

# Passes: three tests
if (($null -eq $objValue) `
        -and ($objValue.Count -gt 0) `
        -and ($objValue[0])) {
    $objValue[0]
}

# Passes: nested -or
if (($colValue.Count -gt 0) `
        -and (($colValue[0] -eq 'a') `
            -or ($colValue[0] -eq 'b'))) {
    $colValue[0]
}

# Passes: a condition inside the if parentheses
if (
    ($null -eq $objValue) `
        -and ($objValue.Count -gt 0)
) {
    $objValue[0]
}

# Fails: the Where-Object predicate tests are on one line
$objPipeline | Where-Object { $_.Count -gt 0 -and $_.Name }

# Passes: the Where-Object predicate tests are split
$objPipeline | Where-Object {
    ($_.Count -gt 0) `
    -and ($_.Name)
}
```

Every operand of an `-and` or `-or` chain must be a parenthesized expression and
start on its own line. The operator starts the continuation line, so the logic
split stays visible at the left edge. A chain of the same operator is read left
to right, so three or more tests produce one operator line per test. A nested
`-and` or `-or` is checked recursively, and a leading `-not` is traversed so the
enclosed chain is still checked. PowerShell operator precedence is preserved:
mixed `-and` and `-or` levels are checked separately, and a grouped test must
be parenthesized. A single test and an `if` expression are not compound
conditions and are not reported. `Where-Object` predicates are found through
the cmdlet name, its `?` and `where` aliases, and a module-qualified name, with
either a positional script block or `-FilterScript`. Simplified syntax such as
`Where-Object Name -eq 'abc'` and a filter passed by variable are not checked.
Test files, tepp fixtures, and `build/` scripts are exempt. The rule runs on
module code (public and internal).

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1MultilineIfConditionRule.ps1
```

## Central API version

`PSUseCentralApiVersion` keeps API versions in one registry,
`$script:BapApiVersions` in `d365bap.tools/internal/scripts/initialize-sdk.ps1`.
The version in a URL comes from a variable, never a literal, so a version bump
is a one-line change:

```powershell
# Fails
$uri = "https://api.powerplatform.com/authorization/roleAssignments?api-version=2024-10-01"
$apiVersion = '2024-10-01'

# Passes
$apiVersion = $script:BapApiVersions.PowerPlatform
$uri = 'https://api.powerplatform.com/authorization/roleAssignments?api-version={0}' `
    -f $apiVersion
```

The rule reports a string literal that contains `api-version=` followed by a
digit, and an assignment to a variable whose name ends in `apiVersion` when the
value is a date literal or an `if` expression that contains one. Plain copies
such as `$apiVersion = $script:BapSdkApiVersion` are allowed.

Here-strings are exempt because they document example requests, and a format
placeholder never contains a digit directly after `=`. The registry file is
exempt from the assignment check only; a literal URL there still fails. Test
files, tepp fixtures, and `build/` are out of scope. The companion
`PSUseFormattedUrl` rule owns the `-f` requirement.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ObjectArrayCastRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ValidationAttributeOnMandatoryRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1WildcardParameterAsFilterRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1OrderedPSCustomObjectRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1OutNullRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1StandardExcelExportRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1LoopAppendRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1OneParameterPerLineRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1CentralApiVersionRule.ps1
```

## URL formatting

`PSUseFormattedUrl` requires URL string manipulation to use the format operator
(`-f`). Interpolation and concatenation are reported:

```powershell
# Fails
$uri = "https://api.powerplatform.com/environments?api-version=$apiVersion"
$uri = 'https://api.powerplatform.com/environments' + $EnvironmentId
$uri = 'https://api.powerplatform.com/environments?api-version={0}' -f $apiVersion
$uri = 'https://{1}.example/{0}' -f $Region, $Tenant
$uri = 'https://{0}.example/{1}' -f $Tenant, $Region

# Passes
$uri = 'https://api.powerplatform.com/environments?api-version={0}' `
    -f $apiVersion
$uri = 'https://{0}.example/{0}' `
    -f $Tenant
$uri = 'https://{0}.example/{1}' `
    -f $Tenant,
    $Region
```

A string that contains `https://`, `http://`, or `api-version=` and interpolates
a value is reported; a plain literal URL and a non-URL string are not. A URL
string built with `+` is reported when one side contains URL text. `-f` always
starts its own continuation line. With more than one input, each input gets its
own line. Placeholders start at `{0}` and must not move backwards; repeats are
allowed. Here-strings are exempt because they document example requests. Test
files, tepp fixtures, and `build/` are out of scope.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1FormattedUrlRule.ps1
```

## Null comparisons

`$null` always sits on the left of a comparison. Two rules enforce the style:

- The built-in `PSPossibleIncorrectComparisonWithNull` reports a `$null` on the
  right. It is in the fatal high-signal set for module and build code.
- `PSAvoidNotEqualNull` reports `-ne` or `-cne` with `$null` on the left.
  Negation goes through `-Not` around a positive `$null -eq` test.

```powershell
# Fails: null on the right (built-in)
$x -eq $null
$x -ne $null
$Value -ceq $null
$Value -cne $null
$Value -eq $NULL
$Value -ine $null

# Fails: -ne with null on the left (repository rule)
$null -ne $x
$null -cne $x

# Passes
$null -eq $x
$null -ceq $x
-Not ($null -eq $x)
-Not ($null -ceq $x)

# Passes: simplified Where-Object cannot put null on the left
Where-Object Name -ne $null
```

The scriptblock form `Where-Object { $_.Name -eq $null }` is reported by the
built-in. The simplified form is not, because a property name cannot be the
right side of a `$null -eq` test.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1NullComparisonRule.ps1
```

## Direct value in string checks

`PSUseDirectValueInStringCheck` rejects an interpolated string that wraps a
single value for `[string]::IsNullOrWhiteSpace` or `[string]::IsNullOrEmpty`.
The method already converts the value to a string, so the wrapper adds nothing
and hides the value being tested:

```powershell
# Fails
if (-not [string]::IsNullOrWhiteSpace("$($created.id)")) { ... }
if ([string]::IsNullOrWhiteSpace("$policyName")) { $policyName = $colCurrent[0].PolicyId }

# Passes
if (-not [string]::IsNullOrWhiteSpace($created.id)) { ... }
if ([string]::IsNullOrWhiteSpace($policyName)) { $policyName = $colCurrent[0].PolicyId }
```

A string with literal text (`"prefix $name"`), a string with more than one
expression (`"$first$last"`), and a single-quoted literal are real string
compositions and stay clean. An instance method with the same name is not
checked. Test files, tepp fixtures, and `build/` scripts are exempt. The rule
runs on module code (public and internal).

## Empty line after continuation

`PSUseEmptyLineAfterContinuation` requires an empty line after a statement that
ends through a backtick line continuation, before the next statement in the same
block:

```powershell
# Fails
$tokenValue = ConvertFrom-SecureString -AsPlainText `
    -SecureString $objSecureToken
$apiVersion = $script:BapApiVersions.PowerPlatform

# Passes
$tokenValue = ConvertFrom-SecureString -AsPlainText `
    -SecureString $objSecureToken

$apiVersion = $script:BapApiVersions.PowerPlatform
```

The empty line makes it clear that the continuation has ended and that the next
line is a new statement, not a continuation line with different indentation. A
comment line directly after the continuation also separates the statements. A
closing brace, a comment, or the end of the block needs no empty line. A
multi-line expression that ends with a visible delimiter, such as `)` or `}`, is
not reported. Test files and tepp fixtures are exempt. The rule runs on module
code (public and internal).

## Direct parameter checks

`PSUseDirectParameterCheck` requires module code to test the parameter itself
instead of `$PSCmdlet.ParameterSetName` or `$PSBoundParameters.ContainsKey`:

```powershell
# Fails
if ($PSCmdlet.ParameterSetName -eq 'EnvironmentGroup') { ... }
$isByEnvironment = $PSCmdlet.ParameterSetName -eq 'ByEnvironment'
$buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
if ($PSBoundParameters.ContainsKey('Description')) { $payload.description = $Description }

# Passes
if ($EnvironmentGroupId) { ... }
$isByEnvironment = [bool] $EnvironmentId
$buildGiven = -not [string]::IsNullOrWhiteSpace($Build)
if (-not [string]::IsNullOrEmpty($Description)) { $payload.description = $Description }
```

A parameter whose default is also a valid explicit value is exempt, because the
value cannot tell omitted from explicit. `$Asset = '*'` is the example:
`$PSBoundParameters.ContainsKey('Asset')` is allowed. A mandatory parameter is
reported as always bound. `$PSBoundParameters` passed as a value
(`-BoundParameters $PSBoundParameters`) and a dynamic key (`ContainsKey($name)`)
are not checked.

The message for an optional non-string parameter says to trust its null value
and test `-not ($null -eq $Parameter)` directly; it does not ask for a
`= $null` default. An omitted `[string]` parameter is empty, not `$null`, so
the message for a string points to `[string]::IsNullOrEmpty($Parameter)` or
`if ($Parameter)` instead.

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1DirectStringCheckRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1EmptyLineAfterContinuationRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1DirectParameterCheckRule.ps1
```

## Return after Stop-PSFFunction

`PSUseReturnAfterStopPSFFunction` requires a plain `Stop-PSFFunction` to be
followed by `return`, `throw`, or `exit` before any later statement runs. The
rule walks out through enclosing blocks, so a stop at the end of an inner block
is reported when the function continues after that block:

```powershell
# Fails: the function continues after the if block
if ($null -eq $thing) {
    Stop-PSFFunction -Message 'Not found'
}
Get-Thing

# Fails: continue does not return from the function
if ($null -eq $thing) {
    Stop-PSFFunction -Message 'Not found'
    continue
}

# Passes
if ($null -eq $thing) {
    Stop-PSFFunction -Message 'Not found'
    return
}

# Passes: the function ends at the stop
if ($null -eq $thing) {
    Stop-PSFFunction -Message 'Not found'
}

# Passes: explicit continuation
Stop-PSFFunction -Message 'Try the next one' -Continue
```

`-StepsUpward`, `-EnableException $true`, and `-Continue` are exempt because
they do not fall through to the next statement in the same way. Test files and
tepp fixtures are exempt. The rule runs on module code (public and internal).

## Pipeline continuation

`PSUsePipelineContinuationBreak` requires a pipeline with more than one command
to break after each pipe. A multiline hashtable that closes with `}` keeps the
pipe and the next command on the closing brace line. Any other element breaks
after the pipe:

```powershell
# Fails
$envObj = Get-Environment -EnvironmentId $EnvironmentId | Select-Object -First 1

# Fails: a backtick continuation keeps the next command on the same line
$objRoute = Get-Route `
    -Name 'fixture' | Select-Object -First 1

# Fails: a closing parenthesis keeps the next command on the same line
$objRoute = (Get-Route `
    -Name 'fixture') | Select-Object -First 1

# Fails: leading pipe
$envObj = Get-Environment -EnvironmentId $EnvironmentId
    | Select-Object -First 1

# Passes
$envObj = Get-Environment -EnvironmentId $EnvironmentId |
    Select-Object -First 1

# Passes: a backtick continuation breaks after the pipe
$objRoute = Get-Route `
    -Name 'fixture' |
    Select-Object -First 1

# Passes: a closing parenthesis breaks after the pipe
$objRoute = (Get-Route `
    -Name 'fixture') |
    Select-Object -First 1

# Passes: the closing brace, the pipe, and the next command share a line
$body = [ordered]@{
    name     = $Name
    ruleSets = @($RuleSet)
} | ConvertTo-Json -Depth 20

# Fails: the pipe and the next command leave the closing brace line
$body = [ordered]@{
    name     = $Name
    ruleSets = @($RuleSet)
} |
    ConvertTo-Json -Depth 20
```

A multiline element ending with `}` keeps `|` plus the next command on that
line. Any other element, including a backtick continuation or a closing
parenthesis, starts the next command on a new line. A single-command pipeline is
not checked. A pipe inside a string is not a pipeline. Test files and tepp
fixtures are exempt. The rule runs on module code (public and internal).

Run its regression checks under PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ReturnAfterStopRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1PipelineContinuationRule.ps1
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
