# Module command splatting

In ModuleSource (d365bap.tools/functions and d365bap.tools/internal), excluding *Tests.ps1 and internal/tepp, known module functions must receive explicit parameters. The repository index recognizes function names case insensitively, including nested functions, plain names and d365bap.tools-qualified names. A known module call reports each splat separately.

A splatted command whose AST GetCommandName cannot resolve reports one unsupported-target diagnostic per command. Use a literal target or explicit named arguments. Variables, expandable or computed targets and scriptblocks are not evaluated or propagated. A dynamic target without a splat is allowed. Static external targets, including & az @cliArgs and other module-qualified commands, are allowed. Strings and comments are not commands. The index is loaded only for a splatted static candidate; unresolved targets are diagnosed even without a module root.

An AST inventory of the current in-scope module source found no unresolved splatted targets. It parsed files without executing module code and included multiline commands.

Static membership checks need a discoverable module root and its repository
index; unknown static names are not proof of external ownership. Arbitrary alias
resolution, shadowing and dynamic value propagation are not attempted here.
Alias policy is enforced separately. There are no new dynamic-call exemptions.

Validation:

```powershell
pwsh -NoProfile -NonInteractive -File build/Test-Ps1ModuleSplattingRule.ps1
```

The direct no-root fixture also verifies one diagnostic at the command location
for multiple unresolved splats and no repository-index build for that path.
