# Add-Member in loops

`PSAvoidAddMemberInLoop` checks module and lint tooling scripts for recognized note properties added within PowerShell loops, `ForEach-Object`, and the `ForEach` method. It recognizes the plain commands and the `Microsoft.PowerShell.Utility\Add-Member` and `Microsoft.PowerShell.Core\ForEach-Object` names. Use full parameter names, including `-NotePropertyName` or `-MemberType NoteProperty -Name`, and a variable pipeline target or `-InputObject`. Colon-attached arguments are supported.

A literal property name and a variable target are required. Computed names, non-variable targets, abbreviated/unknown/duplicate parameters, bulk note properties, dynamic member types, positional-only calls, and explicit splatting produce an unsupported-form diagnostic. Other member types are outside this rule. An addition with no recognized read produces a diagnostic suggesting review of a projection after the loop; moving it can change behavior.

A direct property read, compound update, increment or decrement, or a write to a nested member counts as a read. A simple assignment to the property itself, including a destructuring target, does not. Matching is syntactic and case-insensitive, within the same script block as the addition and the enclosing iteration; nested functions and script blocks do not count. Additions within deferred nested code do not inherit an outer loop; their own loops are checked normally. Only the same variable name matches, with `$_` and `$PSItem` treated as equivalent. This does not track aliases, object identity, control flow, execution order, or data flow. It can therefore miss or overcount reads and does not prove runtime behavior.

Run the focused checks with PowerShell 7.6 or later:

```powershell
pwsh -NoProfile -File build/Test-Ps1AddMemberRule.ps1
```
