# Discarding output

Discard success-stream output with `<expression> > $null`. This preserves the expression and its side effects and leaves other streams available. For keyword statements, use `$(<statement>) > $null`.

The rule flags `Out-Null`, `$null =` assignments, and `[void]` or `[System.Void]` casts. It checks explicitly qualified `Microsoft.PowerShell.Core\Out-Null` even when a local command shadows the name. When a file defines an `Out-Null` function or alias, unqualified calls are conservatively excluded because static analysis cannot reliably resolve the command. Other module-qualified commands are outside the rule.

This is a syntax convention, without an automatic rewrite or a speed claim.
Type metadata such as `[OutputType([void])]` is allowed. A void cast used inside
a larger expression needs a manual rewrite preserving evaluation and output.

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1OutNullRule.ps1
```
