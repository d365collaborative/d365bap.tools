# Select-Object projection contract

Static `Select-Object`, `Microsoft.PowerShell.Utility\Select-Object`, `Select-PSFObject`, and `PSFramework\Select-PSFObject` projections use the full `-Property` parameter and literal property names or calculated-property hashtables. Calculated properties use full `Name` then `Expression` keys, with a scriptblock expression. When a list contains a calculated property, each property occupies a separate line. Simple lists can share a line. Non-projection parameters such as `-First`, `-Skip`, `-Last`, `-ExpandProperty`, and Select-PSFObject extras (`-TypeName`, `-KeepInputObject`, `-ShowProperty`, `-ShowExcludeProperty`, `-ScriptMethod`, `-ScriptProperty`) do not require `-Property`.

Variable and splatted projections are unsupported; replace them with an explicit literal list. Aliases are handled by the alias rule. The rule parses syntax without executing source code. Complex dynamic forms and parameter abbreviations outside `-Property` are not fully modeled.

The generic complex-array rule defers direct Select-Object / Select-PSFObject property-list layout to this rule when both are loaded. One `PSUseStandardSelectObject` diagnostic owns the complete convention. Each command reports its first violation, in order: supported syntax, explicit parameter, property structure, then layout. One file implements all checks. Expression values are checked as scriptblock AST nodes, without executing them.

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1SelectObjectPropertyRule.ps1
pwsh -NoProfile -File build/Test-Ps1ComplexArrayElementRule.ps1
```
