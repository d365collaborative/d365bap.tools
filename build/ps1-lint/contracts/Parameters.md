# Parameter contracts

Explicit position diagnostics apply only when all explicit positions in a module
parameter block repeat zero-based declaration order. Named parameter sets,
PositionalBinding disabled or computed, reordered/nonliteral positions, and
function dynamic parameters are excluded. The check follows parameter metadata,
not filenames. Script-level parameter blocks use the same declaration-order
boundary. Removing a redundant argument does not authorize removing other
attributes or changing the public parameter contract.

An explicit position can supply binding that is absent when PositionalBinding
is disabled. Retain that slot. Do not reorder declarations or delete meaningful
positions to satisfy style. Runtime fixtures cover both preserved explicit slots
and the supported redundant declaration-order case.

Optional parameters may use ValidateNotNullOrEmpty without a default. Omission is valid, while an explicitly supplied empty value fails binding. Do not make such a parameter mandatory, add a default, or replace its validation merely to silence lint: those changes can alter binding and PSBoundParameters behavior. The old validation rule and its dispatch entry are removed.

## Mandatory string parameters

`PSUseValidateNotNullOrEmpty` requires a mandatory `string` or `string[]`
parameter without a default value to declare `[ValidateNotNullOrEmpty()]`.
PowerShell already rejects null and empty values when it binds a mandatory
string parameter; the attribute states the contract in the signature.

A parameter with any default assignment is exempt. Value types such as `switch`
and `int` are exempt because `[ValidateNotNullOrEmpty()]` has no effect on them.

`PSAvoidShorthandMandatory` bans `[Parameter(Mandatory)]` and requires the
explicit `[Parameter(Mandatory = $true)]` form.

```powershell
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
)
```

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1ParameterPositionRule.ps1
pwsh -NoProfile -File build/Test-Ps1ValidationAttributeOnMandatoryRule.ps1
pwsh -NoProfile -File build/Test-Ps1MandatoryRule.ps1
```
