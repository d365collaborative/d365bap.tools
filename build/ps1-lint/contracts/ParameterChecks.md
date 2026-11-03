# Parameter checks

Test values when their value matters, use $PSBoundParameters.ContainsKey('DeclaredName') when explicit supply matters, and inspect $PSCmdlet.ParameterSetName when the selected set matters. Explicit false, zero, empty, and null differ from omission; defaults and parameter sets also affect these decisions.

Use ContainsKey with the declared name, not an alias. Known literal aliases are reported. Unknown keys, including common and dynamic parameters, are allowed. Dynamic keys are allowed without membership validation. Dynamic parameters and dynamic method names are outside analysis. Contains is reported; unknown arguments are preserved.

Validate with PowerShell 7.6 or later: pwsh -NoProfile -File build/Test-Ps1ParameterPresenceRule.ps1

`PSUseExplicitParameterPresenceCheck` owns the spelling and known alias-key checks.
It replaces the old direct-value heuristic, which could change behavior. Wildcard
metadata does not make explicit supply equivalent to a value check, so the
wildcard validator no longer rejects presence checks. A combined fixture checks
that both owners accept a wildcard parameter's canonical presence query.

Runtime fixtures distinguish omission from explicit false, zero, empty, null,
and default-valued arguments, and preserve parameter-set selection. The scope
is module source; this rule does not validate arbitrary dictionary membership.
