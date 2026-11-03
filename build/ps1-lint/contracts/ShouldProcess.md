# ShouldProcess convention

Functions declaring SupportsShouldProcess must call `$PSCmdlet.ShouldProcess` with `$shouldAffected` and `$shouldLabel`. Assign those variables on consecutive lines immediately before the guard, with one blank line before the guard. The target must include a human-friendly name, and the label must be a descriptive string literal. The rule also checks estimated length limits of 85 and 125 characters respectively.

A ShouldProcess call without SupportsShouldProcess is also rejected. Only the
two-argument form is accepted, in target/action order. Literal strings and
interpolated strings with descriptive literal text can serve as labels; a bare
variable or interpolation containing only an identifier does not qualify.
The human-target check recognizes variable/member names containing name,
displayname, title, text or description. These spelling checks are heuristics;
reviewers still verify that the actual confirmation text describes the action.

Length checks are estimates. Literal text contributes its written length;
each variable, member access, or interpolated subexpression contributes 36
characters. Concatenation sums the estimates, and parentheses are transparent.
Unsupported expression forms contribute zero, so this is not a runtime length
guarantee. Target and action estimates may not exceed 85 and 125 respectively.

The guard condition must be exactly `-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)`, allowing parentheses around the condition or the call. It cannot have `elseif` or `else` branches. Its body must contain a bare `return`, optionally preceded by a single unqualified local variable output expression, such as `$preview; return`. A valued return is rejected. Commands, assignments, multi-element pipelines, redirects, background pipelines, trap blocks, scoped variables, member access, and other work are not permitted in the declined branch.

This convention does not establish side-effect safety elsewhere in the function. Prepare preview data safely before the guard and place confirmed mutations after it.

The variable output check verifies unqualified syntax, not whether the variable
was assigned locally or how its value was prepared. Guard parentheses must be
single-expression wrappers without redirections or background execution.
Existing declaration, argument, target/label content and length, and assignment
adjacency checks still apply. Scope remains module source excluding tests and
tepp. Class methods and other non-function code keep their existing policy.

```powershell
$preview = 'prepared preview'
$shouldAffected = $envObj.EnvName
$shouldLabel = 'Apply the prepared change'

if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) {
    $preview
    return
}
```

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1ShouldProcessRule.ps1
pwsh -NoProfile -File build/Test-Ps1ReturnValueRule.ps1
```

The suite checks both rules together and uses an isolated local file to verify
that -WhatIf emits prepared preview output without mutation, while an accepted
call performs the mutation. No external service or approval prompt is involved.
