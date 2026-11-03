# Comment-based help authoring contract

These rules describe the current repository diagnostics, not a promise that all
help is complete. Use PowerShell comment-based help attached to the function or
script. In documentation scope, ordinary comments are rejected; `#region` and
`#endregion` markers are allowed. `#requires` and a leading shebang are ignored.
Both block help and consecutive line comments can be recognized as help.

Comment placement uses the central Documentation scope: it applies to analyzed
module scripts and analyzed scripts outside the module, except files under
`build/`, `*Tests.ps1`, the module test folder, `*.tepp.ps1`, and the module tepp
folder. Build and lint tooling comments are exempt. This scope controls
`PSOnlyCommentBasedHelp`; it does not disable section-content checks for help
that those files do contain. Public help completeness has the narrower
filename/function scope described below.

```powershell
function New-Fixture {
<#
.SYNOPSIS
    Creates a fixture.
.DESCRIPTION
    Provisions a sample environment for testing.
.PARAMETER Name
    Display name.
.PARAMETER Template
    Provisioning template.

    Default: Developer
.EXAMPLE
    PS C:\> New-Fixture -Name demo

    Creates a sample environment.
    It uses -Name demo.
    It uses the default -Template Developer.
.NOTES
    Tags: testing, environment
    Author: Example Author
.LINK
    https://example.org/source
#>
    param([string] $Name, [string] $Template = 'Developer')
}
```

Keep attribution: citations can go in `.LINK`, which passes both the help and
comment rules. The claim that NOTES restrictions make citations unsatisfiable is
incorrect; NOTES itself permits only the entries below.

## Enforced sections

Section content is trimmed line by line; character limits include internal
newlines. SYNOPSIS is one line and fewer than 60 characters. DESCRIPTION is
fewer than 250 characters with at most two blank lines; it must not mention a
parameter name or dash-prefixed parameter-like word, or contain the normalized
synopsis (case and whitespace ignored, trailing periods removed).

PARAMETER content is fewer than 100 characters and has at most two blank
lines, or three for a parameter with a code default. Such parameters must have a
matching section by name or alias, with a nonempty `Default: ...`, `Defaults
 to ...`, or `Default value is ...` line in its final paragraph. The rule does
not compare that text to the actual value. NOTES permits at most one `Tags:`
line with at least two nonempty comma-separated entries and any number of
nonempty `Author:` lines; no other lines are allowed. Other sections, including
LINK, have no section-specific checks here.

## Examples

Each EXAMPLE has parseable PowerShell code followed by exactly one blank line
and prose without blank lines. Prompt prefixes `PS ...>` and `>>` are stripped.
An optional first summary that does not start with `It ` is fewer than 125
characters. All remaining lines start with `It ` and have at most 80
characters. Prose must stand alone rather than refer to another example.

Each named parameter in every parsed command needs its own `It` line mentioning
its dash-prefixed name. For the documented command, positional arguments are
matched to declared positions and aliases count; unmatched positionals and
splatting are reported. Omitted code defaults and defaults described in
parameter help also need a line, except implicit wildcard search defaults.
Explicit wildcard arguments still need explanation. These are textual coverage
checks, not execution or proof that an explanation is accurate.

## Analysis limits and future work

For a public function in `functions/<Name>.ps1` matching the filename, require
nonempty SYNOPSIS, DESCRIPTION, and at least one EXAMPLE. Each explicitly declared
parameter requires exactly one nonempty PARAMETER section; an exact declared
alias may identify it. Unknown parameter names and duplicate parameter sections
are rejected. SYNOPSIS, DESCRIPTION, and NOTES are singletons; EXAMPLE and LINK
may repeat. NOTES and LINK are optional.

Help groups carry the owning function's source offset, so a nested helper's help
cannot satisfy the public function's requirements. Missing help is anchored at
the public function name. `PSHelpStructure` owns missing required sections and
duplicate singleton sections; `PSHelpParameter` owns parameter coverage. Existing
section-specific rules still validate content. Internal and build help retains
its previous completeness policy. Public files without a matching top-level
function remain outside this completeness check.

The validator does not verify link targets, semantic accuracy, or command
execution. Position and default inference is static and cannot model all binding
behavior. Future work should improve static binding analysis independently.

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1ExampleHelp.ps1
pwsh -NoProfile -File build/Test-Ps1CommentRule.ps1
```

The suite includes combined help/comment fixtures for complete public help,
missing/empty/duplicate sections, unknown parameters, aliases, nested-function
ownership, invalid NOTES content, and ordinary comments, with LF and CRLF cases.
