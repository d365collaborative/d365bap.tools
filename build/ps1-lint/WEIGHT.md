# Keep lint weight lean

Prefer the enforcer. Cut duplicated docs, redirect stubs, and paraphrased fixtures.

## Docs

- Policy lives once in `contracts/*.md` (or the main README for uncontracted rules).
- Do not restate a contracted rule in README, and do not add redirect stubs between contracts.

## Rule suites

- Prefer [`testing/Assert-Ps1RuleCase.ps1`](testing/Assert-Ps1RuleCase.ps1) for `Test-Ps1*Rule.ps1`.
- Stay custom only when the harness cannot cover the case (today: Alias allowlist config, ModuleSplatting ExtraFiles/AllRules).
- Build/Tepp path exemptions belong in `Test-Ps1LintCorrectness` Analysis.Scope. Keep at most one Test-files smoke case per suite; do not rephrase Build/Tepp exemptions in every suite.
- Simple numeric limits (SYNOPSIS/DESCRIPTION/PARAMETER length, example summary/line length) live in the rule and contract. Do not add N-1/N knife-edge fixtures when changing a limit; the enforcer already gates real code. Keep fixtures that prove shape or semantics (missing sections, parameter coverage, stand-alone prose), and keep clearly-over-limit cases only when they cover a distinct diagnostic path.

## Infra

- Keep meta suites path-gated. Leave intentional manual suites (for example `Test-PowerPlatformSdk`) out of CI.
- Do not pin documentation wording, diagnostic prose, YAML action versions, or cache-key syntax in tests. Keep trust-boundary checks (narrow installs, check-only CI, verified prek install, failure propagation, cache invalidation).
- Rule suites: discovery (`Test-Ps1*Rule.ps1`) is the inventory. Validation suites: `Get-ValidationSuitePlan` `SuitePattern` keys are the inventory; `Test-ValidationSuites` keeps intentional `$notSuite` exclusions only.
