# Wildcard parameters

The wildcard convention is one contract for declarations and use. It reports
`PSUseWildcardParameterContract`. The old `PSUseSupportsWildcards` and
`PSUseWildcardParameterAsFilter` identifiers are replaced by this one rule.

## Scope

The rule runs on `FunctionFile`: `d365bap.tools/functions` and
`d365bap.tools/internal/functions`, excluding `*Tests.ps1`.

The declaration checks used to scan every function in a file that a broader
parameter-contract pass reached, including build scripts, internal scripts,
and SDK wrappers. They now stop at the same `FunctionFile` boundary as the use
checks. No SDK or build coverage was added. A parameter is checked only when it
belongs to a function in this scope; script-level parameters are not checked.

## Declaration contract

A parameter needs the wildcard shape to stay consistent:

1. A `string` or `string[]` parameter with a constant string default that
   contains `*` must declare `[SupportsWildcards()]`. `'*'` and `'demo*'` both
   count.
2. A parameter that declares `[SupportsWildcards()]` must default to `'*'`.
   This is the default-value convention for a filter parameter.
3. A declared wildcard parameter must not use `-eq`, `-ne`, `-ceq`, or `-cne`
   against the literal `'*'` as a mode selection. Pass the value to the filter
   instead.

```powershell
param (
    [SupportsWildcards()]
    [string] $Name = '*'
)

$result | Where-Object Name -like $Name
```

A parameter is wildcard-shaped when it declares `[SupportsWildcards()]` or has
a constant string default containing `*`. A presence check such as
`$PSBoundParameters.ContainsKey('Name')` stays valid because it asks whether the
caller supplied the parameter, not whether the current value matches `'*'`.

The declaration heuristic looks only for `*` in literal defaults. Other
wildcard syntax is outside that detection; runtime PowerShell matching still
supports its normal wildcard syntax.
The rule reads the AST, so wildcard text inside a string that is not the
declaration default and text inside a comment are ignored. Non-string, nonliteral, and expandable defaults do not infer wildcard shape
on their own. An explicit SupportsWildcards attribute still requires the literal
star default, including when the current default is dynamic. Script-level parameters and files outside `FunctionFile` are not
checked.

## Use identity

The comparison check uses syntactic declared-parameter identity. It recognizes
an unqualified name and a `local:`-qualified name, case-insensitively.
Single-expression parentheses around either comparison operand are transparent.
`script:`, `global:`, and any other scope qualifier are different variables and
are not reported. A name is reported only when it belongs to the current
function's parameter list and that parameter is wildcard-shaped.

Assignments do not exempt the name. `$Name = 'All'; if ($Name -eq '*')` and
`$Name = $Name; if ($Name -ne '*')` are both reported. The rule does not model
which value is current at a comparison.

Each function owns its own reads. A nested function's parameter list is checked
at the nested function, and a read inside a nested function is not reported as
the parent function's use. A nested helper that reads the parent's parameter and
compares it with `'*'` is therefore outside this rule. The rule does not trace
helper call graphs.

## Diagnostics

The rule always reports `Error` severity:

- `Parameter -Name has a wildcard default value. Add [SupportsWildcards()] to
  the parameter.`
- `Parameter -Name declares [SupportsWildcards()] but does not default to '*'.
  The wildcard contract uses '*' as its declaration default; review callers before changing it.`
- `Parameter -Name is a wildcard filter. Do not compare it with the literal
  '*'; pass the value to the filter.`

## Limits and behavior

The rule does not evaluate input code, resolve aliases, or build arbitrary
dataflow. A parameter reference is matched by name and owner only. A local
variable that shadows a wildcard parameter can therefore still be reported when
it compares against `'*'`; that is the price of not guessing at runtime values.
Member expressions such as `$_.Name -eq '*'`, comparisons with another literal,
and comparisons with a variable are not reported. `-like` is the intended
filter operation and is not reported.

The default and the filter are runtime behavior. Omission of a wildcard
parameter whose default is `'*'` returns all items, an exact value narrows to
that value, a pattern matches the pattern, and a pattern with no match returns
nothing. Changing a default, removing `[SupportsWildcards()]`, or replacing a
filter with a comparison can change caller-visible results and parameter
binding. Review the callers before changing these declarations. The rule never
rewrites a default or a filter.

## Validation

Run these commands from the repository root with PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1WildcardRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1WildcardParameterAsFilterRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1EmptyAttributeRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1MandatoryRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ParameterArgumentRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ParameterPositionRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ValidationAttributeOnMandatoryRule.ps1
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ParameterPresenceRule.ps1
```

The wildcard suites include a combined accepted declaration and use fixture, a
combined failing fixture, both operand orders for every comparison operator,
assignment and self-assignment cases, `local:` qualification, unrelated
`script:` and `global:` variables, nested-owner isolation, a valid presence
check, and the scope exclusions. The declaration suite also runs a small local
filter fixture that records omitted `'*'`, exact, pattern, and no-match
behavior. The fixture defines its own function; no public function is changed.
