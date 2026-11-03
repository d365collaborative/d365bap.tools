# Ordered PSCustomObject literals

In module source, construct a PSCustomObject from a literal as
`[pscustomobject][ordered]@{ ... }`. The type name is case insensitive and
`[System.Management.Automation.PSCustomObject]` is also recognized. Parentheses
around the ordered expression or its literal are transparent when they contain
a single expression.

A direct hashtable literal or a literal reached through any other cast chain
is diagnosed. In particular, `[pscustomobject][hashtable][ordered]@{}` is not
accepted: the intervening cast does not preserve the required construction.
Each nested PSCustomObject literal is checked separately. Conversions of
variables and other nonliteral expressions are outside this policy; the rule
does not infer their values. Strings and comments are not analyzed as code.
The rule applies to module source, excluding test files and exempt directories.

Run the focused checks with:

```powershell
pwsh -NoProfile -File build/Test-Ps1OrderedPSCustomObjectRule.ps1
```
