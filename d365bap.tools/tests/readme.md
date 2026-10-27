# Description

This is the folder, where all the tests go.

Tests are grouped by purpose:

 - General
 - Function
 - Behavior

## General Tests

General tests are function generic and test for general policies.

These test scan answer questions such as:

 - Is my module following my style guides?
 - Does any of my scripts have a syntax error?
 - Do my scripts use commands I do not want them to use?
 - Do my commands follow best practices?
 - Do my commands have proper help?

Basically, these allow a general module health check.

These tests are already provided as part of the template.

## Function Tests

A healthy module should provide unit and integration tests for the commands & components it ships.
Only then can be guaranteed, that they will actually perform as promised.

However, as each such test must be specific to the function it tests, there cannot be much in the way of templates.

The function files are generated metadata snapshots, not independent behavior
tests. Release validation regenerates them before execution; the PR signature
gate compares declarations with the base separately. Do not update snapshots
by hand to accept an interface change.

The function test runner groups files into batches of 20 and writes one NUnit
report per batch in `TestResults`. Filename-based include and exclude filters
still select individual test files. Delete old reports before comparing results
from runs with different selections.

## Behavior Tests

`tests/behavior` contains offline tests of user-visible behavior. Run them with
`pwsh -NoProfile -File ./build/Test-Behavior.ps1`. The FinOps catalog tests use
source functions with local service adapters; the compiled import check covers
the packaged module separately.

Changes to the test runners or analyzer test trigger the validation-runner
regression workflow. It can also be run locally with PowerShell 7.6 and the
repository's pinned modules:

```powershell
pwsh -NoProfile -File ./build/Test-PSScriptAnalyzerConsolidation.ps1
pwsh -NoProfile -File ./build/Test-PesterRunners.ps1
```
