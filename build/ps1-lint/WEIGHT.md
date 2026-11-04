# Keep lint weight lean

Prefer the enforcer. Cut duplicated docs, redirect stubs, and paraphrased fixtures.

## Docs

- Policy lives once in `contracts/*.md` (or the main README for uncontracted rules).
- Do not restate a contracted rule in README, and do not add redirect stubs between contracts.

## Rule suites

- Prefer [`testing/Assert-Ps1RuleCase.ps1`](testing/Assert-Ps1RuleCase.ps1) for `Test-Ps1*Rule.ps1`.
- Stay custom only when the harness cannot cover the case (today: Alias allowlist config, ModuleSplatting ExtraFiles/AllRules).
- Build/Tepp path exemptions belong in `Test-Ps1LintCorrectness` Analysis.Scope. Keep at most one Test-files smoke case per suite; do not rephrase Build/Tepp exemptions in every suite.

## Infra

- Keep meta suites path-gated. Leave intentional manual suites (for example `Test-PowerPlatformSdk`) out of CI.
