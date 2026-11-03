# Generic-list copy loops

`PSAvoidLoopAppend` recognizes one bounded copy shape in module source:

```powershell
$colTarget = [System.Collections.Generic.List[object]]::new()
foreach ($item in $colSource) {
    $colTarget.Add($item)
}
```

The immediately preceding statement in the same statement block constructs the
receiver with a parameterless generic List constructor. The constructor is read
from the AST, accepting System.Collections.Generic.List and Collections.Generic.List;
the simple element type spelling permits letters, digits, underscores and dots.
The loop body has exactly one Add invocation and no traps. Its sole argument is
the loop variable. Source and receiver must be distinct variable references,
and the receiver cannot itself be the loop variable. Case-insensitive Add and
single-expression parentheses are supported; redirection/background execution
is not transparent.

The diagnostic asks for review of AddRange source compatibility and behavior.
It provides no automatic rewrite, direct source-assignment advice, UnionWith
alternative, or performance promise. A source variable can still hold a scalar,
null, or incompatible IEnumerable; verify before changing code.

Typed parameters, earlier constructors, intervening assignments, computed
sources, transformed values, extra work, ArrayList, custom receivers, nested
receiver inference and whole-program type flow are outside the rule. This is
an explicit subset, not proof that all other copy loops are optimal.

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1LoopAppendRule.ps1
```

Runtime fixtures compare supported loop and AddRange contents and success
output, retaining target identity and preexisting values. An ArrayList fixture
shows why its emitted Add indices prevent the same recommendation.
