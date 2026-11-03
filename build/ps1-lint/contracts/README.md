# Convention contracts

These contracts cover completed convention families. Other rules remain documented in the [main README](../README.md).

| Contract | Implementation owner | Focused validation suites |
| --- | --- | --- |
| [Help](Help.md) | [`Get-Ps1HelpDiagnostic.ps1`](../internal/Get-Ps1HelpDiagnostic.ps1), [`Get-Ps1CommentDiagnostic.ps1`](../internal/Get-Ps1CommentDiagnostic.ps1) | [`Test-Ps1ExampleHelp.ps1`](../../Test-Ps1ExampleHelp.ps1), [`Test-Ps1CommentRule.ps1`](../../Test-Ps1CommentRule.ps1) |
| [Parameters](Parameters.md) | [`Get-Ps1ParameterContractDiagnostic.ps1`](../internal/Get-Ps1ParameterContractDiagnostic.ps1) | [`Test-Ps1ParameterPositionRule.ps1`](../../Test-Ps1ParameterPositionRule.ps1), [`Test-Ps1ValidationAttributeOnMandatoryRule.ps1`](../../Test-Ps1ValidationAttributeOnMandatoryRule.ps1) |
| [ParameterChecks](ParameterChecks.md) | [`Get-Ps1ExplicitParameterPresenceDiagnostic.ps1`](../internal/Get-Ps1ExplicitParameterPresenceDiagnostic.ps1) | [`Test-Ps1ParameterPresenceRule.ps1`](../../Test-Ps1ParameterPresenceRule.ps1), [`Test-Ps1WildcardRule.ps1`](../../Test-Ps1WildcardRule.ps1) |
| [Wildcards](Wildcards.md) | [`Get-Ps1WildcardParameterContractDiagnostic.ps1`](../internal/Get-Ps1WildcardParameterContractDiagnostic.ps1) | [`Test-Ps1WildcardRule.ps1`](../../Test-Ps1WildcardRule.ps1), [`Test-Ps1WildcardParameterAsFilterRule.ps1`](../../Test-Ps1WildcardParameterAsFilterRule.ps1) |
| [SelectObject](SelectObject.md) | [`Get-Ps1StandardSelectObjectDiagnostic.ps1`](../internal/Get-Ps1StandardSelectObjectDiagnostic.ps1), [`Get-Ps1ComplexArrayElementDiagnostic.ps1`](../internal/Get-Ps1ComplexArrayElementDiagnostic.ps1) | [`Test-Ps1SelectObjectPropertyRule.ps1`](../../Test-Ps1SelectObjectPropertyRule.ps1), [`Test-Ps1ComplexArrayElementRule.ps1`](../../Test-Ps1ComplexArrayElementRule.ps1) |
| [Output](Output.md) | [`Get-Ps1OutputTypeDiagnostic.ps1`](../internal/Get-Ps1OutputTypeDiagnostic.ps1), [`Get-Ps1StandardPublicOutputDiagnostic.ps1`](../internal/Get-Ps1StandardPublicOutputDiagnostic.ps1), shared [`Get-Ps1OutputModel.ps1`](../internal/Get-Ps1OutputModel.ps1) | [`Test-Ps1OutputTypeRule.ps1`](../../Test-Ps1OutputTypeRule.ps1), [`Test-Ps1StandardOutputRule.ps1`](../../Test-Ps1StandardOutputRule.ps1), [`Test-Ps1StandardExcelExportRule.ps1`](../../Test-Ps1StandardExcelExportRule.ps1) |
| [ShouldProcess](ShouldProcess.md) | [`Get-Ps1ShouldProcessDiagnostic.ps1`](../internal/Get-Ps1ShouldProcessDiagnostic.ps1), [`Get-Ps1ReturnValueDiagnostic.ps1`](../internal/Get-Ps1ReturnValueDiagnostic.ps1) | [`Test-Ps1ShouldProcessRule.ps1`](../../Test-Ps1ShouldProcessRule.ps1), [`Test-Ps1ReturnValueRule.ps1`](../../Test-Ps1ReturnValueRule.ps1) |
| [OrderedObject](OrderedObject.md) | [`Get-Ps1OrderedPSCustomObjectDiagnostic.ps1`](../internal/Get-Ps1OrderedPSCustomObjectDiagnostic.ps1) | [`Test-Ps1OrderedPSCustomObjectRule.ps1`](../../Test-Ps1OrderedPSCustomObjectRule.ps1) |
| [DiscardOutput](DiscardOutput.md) | [`Get-Ps1OutNullDiagnostic.ps1`](../internal/Get-Ps1OutNullDiagnostic.ps1) | [`Test-Ps1OutNullRule.ps1`](../../Test-Ps1OutNullRule.ps1) |
| [AddMember](AddMember.md) | [`Get-Ps1AddMemberDiagnostic.ps1`](../internal/Get-Ps1AddMemberDiagnostic.ps1) | [`Test-Ps1AddMemberRule.ps1`](../../Test-Ps1AddMemberRule.ps1) |
| [LoopAppend](LoopAppend.md) | [`Get-Ps1LoopAppendDiagnostic.ps1`](../internal/Get-Ps1LoopAppendDiagnostic.ps1) | [`Test-Ps1LoopAppendRule.ps1`](../../Test-Ps1LoopAppendRule.ps1) |
| [ModuleSplatting](ModuleSplatting.md) | [`Get-Ps1ModuleSplattingDiagnostic.ps1`](../internal/Get-Ps1ModuleSplattingDiagnostic.ps1) | [`Test-Ps1ModuleSplattingRule.ps1`](../../Test-Ps1ModuleSplattingRule.ps1) |

For a focused change, read the relevant contract, edit the implementation and fixtures together, and run its focused command from the repository root. Run broader verification as the change warrants. An accepted fixture must pass all related owners; zero diagnostics alone does not establish semantic safety.

The main README owns architecture, setup, caching, and rules not yet contracted.
For the families listed above, update their contract rather than adding a second
policy description to the main README. The index maps ownership; each contract
states accepted forms, exclusions, diagnostic behavior, and focused commands.

Broader verification from the repository root:

```powershell
pwsh -NoProfile -File build/Test-Ps1RuleSuites.ps1
pwsh -NoProfile -File build/Test-Ps1ExampleHelp.ps1
pwsh -NoProfile -File build/Test-Ps1LintCorrectness.ps1
```

A pull request that only edits files under `build/ps1-lint/` starts the validation-runners workflow and, after #369, selects the example-help and rule-suite jobs.
