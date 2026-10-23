# Simplify d365bap.tools

Implement the fifteen simplifications below while preserving the public command contracts. Give each agent this entire file and assign one task by letter. The coordinator owns integration and final verification.

The source review used commit `f2b1e0e448f36ba1f21dc23fcd84b4eb212a1b1b`. Recheck the assigned files against the actual starting commit. The review identified duplication through source inspection. Establish the test baseline before implementation.

## Coordinate the work

Use a separate checkout for each implementation agent. Record its starting commit and owned files. Commit this plan before handing it to agents whose checkouts start from committed files.

Integrate in this order:

1. Task D establishes the compact signature suite and a separate location for behavioral tests.
2. Task A establishes environment resolution and migrates its callers.
3. Task B consolidates OData pagination on top of A.
4. Task C consolidates provisioning on top of A and D.
5. Task E moves SDK wrapper generation into the build after the shared test infrastructure is available.

C and E can proceed in parallel with B after A and D land. They own different production files. Rebase each branch onto the integrated result before final verification. A must finish its public command sweep before B or C edit those commands.

The additional tasks F, G, and H can start after A and D. They own separate public commands and can run alongside B, C, and E in separate checkouts. Task I can start after D. Task J starts after E because both edit the manifest and packaging script. These dependencies define safe overlap, not a requirement to run every available task at once.

Tasks I and J are small removal tasks. F, G, and H change shared execution logic and need the behavioral checks described below. Keep each task's test files separate from the shared runner owned by D.

For tasks K through O, start K and L after A, C, and D. K can then assess the provisioning helpers without creating a competing installation helper, while L can migrate Graph lookups in the completed provisioning commands. M and O start after A and D and own separate production files. N starts after D, E, and J so the shared CI definition includes the final test discovery and build requirements. Keep N as the sole writer of workflow files during its implementation.

Keep each task in a separate reviewable change. Do not merge or publish as part of a delegated task. Return the implementation, verification results, and remaining concerns to the coordinator.

## Preserve the existing contracts

- Preserve command names, parameter sets, aliases, defaults, pipeline binding, object properties, type names, sorting, and Excel output. Keep helper functions private.
- Preserve each caller's matching and error behavior. Existing commands often select the first environment match. SDK commands require an exact name or GUID. Do not silently give both groups one policy.
- Keep behavioral fixes separate from code movement. If a baseline behavior appears incorrect, record a reproducible case and propose a separate fix.
- Read the applicable `AGENTS.md` files. Use PowerShell 7.6 or newer, as required by the module manifest and `build/AGENTS.md`.

`docs/` contains generated help. Regenerate it through `build/update-docs.ps1` when public help changes. The existing `tests/functions/` files are also generated. Task D owns changes to that workflow and its instructions. Other agents must not hand-edit those files.

Place new behavioral tests in `d365bap.tools/tests/behavior/`, with one task-specific file per area. Task D wires that directory into the normal runner. Mock external requests, token acquisition, and waits. Module import currently starts background token and provisioning work, so account for those side effects when establishing isolated tests.

## Task A: Centralize environment resolution

Own a new internal resolver, its behavioral tests, and the public callers that repeat the lookup and missing-environment handling. Leave `internal/sdk/` and SDK generation files to E. Inventory callers with `rg` before editing, including comparisons that resolve both source and destination environments.

Start with:

- `d365bap.tools/functions/Get-PpacUser.ps1`
- `d365bap.tools/functions/Get-FscmUser.ps1`
- `d365bap.tools/functions/Get-PpePublisher.ps1`
- `d365bap.tools/functions/Compare-BapEnvironmentUser.ps1`

The reviewed pattern calls `Get-BapEnvironment`, selects the first result, and repeats a missing-environment error block. Introduce a narrow helper such as `Resolve-BapEnvironment` under `internal/functions/`. Return the resolved object. Keep token acquisition and endpoint construction outside the resolver.

First capture the existing behavior for a GUID, exact name, wildcard, multiple matches, missing match, and upstream failure. Check how `Stop-PSFFunction` propagates interruption across a helper call. Retain caller interruption checks until tests prove they can be removed.

Migrate one representative command, verify it, and then migrate the remaining callers with the same semantics. Record any intentionally excluded caller and its different behavior. Avoid changing lookup timing or adding cross-command caching.

Accept the change when all equivalent lookup blocks use the helper, private helpers stay unexported, and public output remains equivalent. A missing environment must stop the caller before token acquisition or an operation request. Multiple matches must retain the baseline selection behavior.

Return the caller inventory, exclusions, helper contract, and before-and-after examples to the coordinator.

## Task B: Share OData pagination and retry handling

Own `Get-FscmOdata.ps1`, `Get-PpeOdata.ps1`, a private OData reader, and `tests/behavior/OData.Tests.ps1`. Start after A has migrated these commands.

Both commands maintain page collections, retry counters, delays, and continuation loops. Extract that repeated control flow into a helper such as `Invoke-BapODataRead`. Give it explicit request inputs and traversal options. Keep query construction, cross-company handling, and Excel export in the public commands.

Preserve the F&O continuation rule that rebuilds the URL from the `/data/` path. Dataverse currently follows its returned continuation URL. Express that difference through a small explicit policy or callback. Do not create a general transport framework or migrate unrelated REST calls in this task.

Add behavioral cases for:

- Empty, single-page, and multi-page results, including item order and traversal disabled.
- F&O continuation URLs, Dataverse continuation URLs, query arguments, and `CrossCompany`.
- A throttled request followed by success, retry-counter reset after success, and retry exhaustion.
- Non-throttling errors, throttle delays, and Excel output versus object output.

Verify the actual exception shape used by PowerShell 7.6 before constructing mocks. If the current `WebException` catch misses that shape, report it as a separate correctness issue. Preserve the current partial-result behavior on retry exhaustion during the extraction.

Accept the change when both commands use one pagination and retry loop, and request traces and returned objects match the baseline. The shared helper must be exercised through public command tests.

## Task C: Share provisioning stages

Own `New-UnifiedEnvironment.ps1`, `New-UnifiedEnvironmentV2.ps1`, new internal provisioning helpers, and `tests/behavior/Provisioning.Tests.ps1`. Start after A and D. Leave the discovery cache in `internal/sdk/provisioning.ps1` unchanged unless a required dependency is demonstrated.

Read the complete original and V2 flows before extraction. They use different environment-creation APIs, payloads, validation, and error handling. Preserve both creation implementations.

Share the stages that have the same purpose:

- Waiting for environment readiness and the configured post-provisioning delay.
- Installing the Finance and Operations platform package and waiting for its installation.
- Selecting the application version and submitting the provisioning request.
- Waiting for the provisioning application according to `WaitForCompletion`.

Compare each pair of helpers before merging it. Preserve differences in request headers, status handling, and failure behavior with explicit inputs where necessary. Return the environment or application object needed by the next stage. Remove redundant state flags only when the remaining return contract proves the same condition.

Test existing environments, newly created environments, readiness timeouts, failed creation, platform-install retries, version selection, `NoDemoDb`, and both wait modes. Mock sleep and time so tests do not wait in real time.

Test V2 `-WhatIf` explicitly. It must preserve the current absence of authentication and provisioning side effects after `ShouldProcess` declines. Characterize any discovery reads that happen before that check. Do not expand the original command's confirmation behavior in this refactor.

Accept the change when both entry points call shared stages, obsolete duplicate helpers are removed, and both API-specific creation paths remain covered. Record unbounded waits or other discovered defects separately instead of changing their behavior during extraction.

## Task D: Consolidate signature tests and preserve behavioral tests

Own `build/generate-parameterunittests.ps1`, `d365bap.tools/tests/pester.ps1`, generated signature-test artifacts, and the relevant test instructions. Own CI test-discovery changes if required. Do not edit production command implementations.

Replace the per-command assertion boilerplate with a checked-in expected-signature data file and one shared Pester suite. Preserve the useful assertions from the existing generated files. Review command membership, parameter sets, names, types, mandatory flags, positions, dynamic flags, and pipeline-binding attributes. Capture aliases and defaults where they form part of the public contract and can be represented reliably.

Build the expected data from the agreed baseline once. Verification must compare actual commands against that stored baseline. Never regenerate expected data during a test run, because doing so would hide contract changes.

Make the generator deterministic and restrict its writes to generated signature artifacts. Protect the new `tests/behavior/` directory from regeneration. Update `tests/functions/AGENTS.md` in the same change so its instructions describe the new generated artifacts and command. Preserve the existing regeneration entry point where practical.

Wire the contract suite and behavioral tests into the normal runner. Retain existing general tests, failure exit behavior, and usable test reports. Preserve include and exclude filters, or document and test any necessary mapping to the consolidated suite.

Accept the change when a deliberate signature mutation fails the suite with the command and parameter named. Also prove that missing and unexpected exported commands fail. Restore each deliberate mutation after the test. Generate twice and confirm identical artifacts. Verify that existing behavioral tests survive regeneration and that the obsolete per-command boilerplate is removed.

Return the baseline-generation command, verification command, artifact locations, and an example contract failure. Other agents use that workflow for any necessary regeneration.

## Task E: Generate SDK wrappers during the build

Own the SDK generation and import path, its generated wrappers, and SDK-specific tests. Coordinate manifest and build-script changes with the coordinator. Start from the integrated A and D changes.

Read these files together:

- `d365bap.tools/internal/scripts/initialize-sdk.ps1` and `sdk-completion.ps1`.
- `d365bap.tools/internal/sdk/runtime.ps1` and `commands.psd1`.
- `build/Build-PowerPlatformSdk.ps1`, `build/Test-PowerPlatformSdk.ps1`, and `build/vsts-build.ps1`.
- `d365bap.tools/d365bap.tools.psm1`, `internal/scripts/preimport.ps1`, and `internal/scripts/postimport.ps1`.

Move wrapper-source construction and SDK enum inspection into the build. Use the existing command mapping and pinned bundled SDK as the inputs. Generate ordinary PowerShell function files with help, parameter validation, and `ShouldProcess` declarations. Include those files in both source import and the compiled package.

Keep runtime request execution and metadata that runtime genuinely needs. Remove import-time function-string evaluation and generation-only reflection. Do not replace the C# SDK bridge or hand-maintain SDK enum values as part of this task.

Choose the generated file location after checking import order. SDK types must load before any generated declaration that requires them. Keep the runtime command registry and completion registration consistent. Normal module import must use the shipped artifacts without invoking a compiler or restoring packages.

Preserve all three mapped commands, including `Get-PpacTenantD365App`. Test parameters, help, completion, pipeline aliases, result properties, private scope, and repeated import. For maintenance updates, test preservation of omitted settings and no dispatch under `-WhatIf`. For tenant applications, test pagination, filtering, sorting, and Excel output. Retain continuation-host validation.

Accept the change when generated files are deterministic, a second generation has no diff, and source and packaged modules expose equivalent contracts. Remove the superseded generation path in the same change. Extend the existing SDK verifier where it does not cover the tenant application command.

## Task F: Share the UDE download workflow

Own `d365bap.tools/functions/Get-UdeDeveloperFile.ps1`, `Get-UdeNuget.ps1`, a private download helper, and `tests/behavior/UdeDownloads.Tests.ps1`. Start after A and D. Coordinate tests with I, which removes the unused configuration mirror while preserving the AzCopy configuration key.

Both commands build destination paths from signed URLs, skip existing files, retry missing downloads up to five passes, check final file existence, and unblock completed files. The repeated loops start near line 168 in `Get-UdeDeveloperFile.ps1` and line 188 in `Get-UdeNuget.ps1` at the review commit.

Represent each requested download with its URI and destination path once. Move retry orchestration, existing-file checks, and completion checks into one narrow helper. Keep discovery of developer files and NuGet packages in their respective commands. Preserve their different output properties and extraction destinations.

Keep process execution differences explicit. Developer files currently use separate PowerShell windows and wait for their processes. NuGet packages invoke AzCopy directly and capture its output. Share the outer download workflow without changing those launch behaviors or introducing a general job framework. Keep archive extraction and the clear switches in the public commands.

Exercise both public commands with temporary directories and mocked process execution. Cover discovery without `-Download`, all files already present, partial success, a successful retry, retry exhaustion, and missing AzCopy. Check signed URL arguments, paths containing spaces, output ordering, and the addition of `Path` and `ExtractedPath` properties. Verify that failed downloads stop extraction and that clear switches retain their current scope.

Accept the change when both commands use one retry and completion implementation, while their launch and extraction behavior remains equivalent. Treat quoting defects, partial-file validation, and extraction without `SystemMetadata` as separate findings if characterization exposes them. Never use real signed URLs or download large packages in the default tests.

## Task G: Give LocalDB resources one owner

Own `d365bap.tools/internal/functions/Get-SqlCommand.ps1`, `Dispose-SqlCommand.ps1`, `functions/Get-UdeXrefDb.ps1`, `functions/Set-UdeConfig.ps1`, `functions/Clear-UdeOrphanedConfig.ps1`, and `tests/behavior/UdeLocalDb.Tests.ps1`. Start after A and D. Leave the remote JIT database command `Invoke-UdeDbQuery.ps1` outside this task.

LocalDB execution is split between a command factory, a disposal helper, and repeated caller-owned connection management. `Clear-UdeOrphanedConfig` also recreates the connection setup inline. The disposal helper only disposes objects when the connection is open. `Get-UdeXrefDb` closes its reader in `finally` but disposes its command afterward, where an earlier return can skip it.

Introduce one private LocalDB executor that owns its connection, command, and optional reader through `try/finally`. Support only the row reads and non-query operations used by these callers. Keep SQL text, database selection, caller-specific messages, and configuration file operations in the public commands. Preserve the current LocalDB instance, master database, integrated authentication, application name, and command timeout.

Migrate every caller and remove both obsolete lifecycle helpers in the same change. Avoid returning an open reader or command to the caller. Document failure-path cleanup corrections separately from the extraction, and preserve the original operation error instead of replacing it with a disposal error.

Test successful reads, backup and restore command execution, database removal, open failure, execution failure, and failure before a reader exists. Verify disposal of every resource that was created, including a connection that never opened. Verify that failed backup or restore still stops `Set-UdeConfig` and retains its temporary-file cleanup behavior.

Accept the change when LocalDB resource creation and disposal have one implementation, callers preserve SQL and output behavior, and failure tests prove cleanup. Mock database operations by default. Optional LocalDB integration checks must use disposable databases. Do not run the real orphan cleanup against the developer's directories or databases.

## Task H: Replace repeated comparison scans with indexes

Own `d365bap.tools/functions/Compare-BapEnvironmentUser.ps1`, `Compare-BapEnvironmentD365App.ps1`, `Compare-BapEnvironmentVirtualEntity.ps1`, and `tests/behavior/EnvironmentComparisons.Tests.ps1`. Start after A and D.

Each comparison loops over source objects and rescans the destination collection with `Where-Object` and `Select-Object -First 1`. The keys are email, application ID, and entity name respectively. Build a destination index once, then look up each source key directly. Keep each command's projection close to its comparison loop instead of creating a configurable comparison framework.

Preserve PowerShell matching semantics for the actual key types. In particular, retain case-insensitive string matching and the first destination match when keys repeat. Handle null and empty keys explicitly. Preserve skipped source users with no email, source sorting, version conversion, missing-value markers, `ShowDiffOnly`, type names, and Excel options.

The virtual-entity command also makes a destination query for every source name. Leave that request pattern unchanged in this task. The underlying getter does not currently traverse result pages, so replacing targeted queries with one broad fetch could omit records. Record that separate opportunity rather than combining it with the local indexing change.

Test missing and matching records, duplicate destination keys, case differences, null keys, application versions including `N/A`, and differing visibility or change-tracking flags. Compare complete returned objects against baseline fixtures for each command. Verify that request counts and filters remain unchanged.

Accept the change when destination matching uses one index per invocation and the output fixtures remain equivalent. Prove that index construction visits each destination once. Report any timing results separately with the input sizes and mocked network boundary; this task does not claim faster remote APIs.

## Task I: Remove the unused configuration-variable mirror

Own `d365bap.tools/internal/functions/Update-ModuleVariables.ps1`, `Update-PsfConfigVariables.ps1`, `functions/Set-BapAzCopyPath.ps1`, `functions/Set-BapToolsAuthProvider.ps1`, the stale entry in `tests/general/FileIntegrity.Exceptions.ps1`, and `tests/behavior/Configuration.Tests.ps1`. Start after D.

`Update-PsfConfigVariables` creates script variables by converting configuration names into variable names. `Update-ModuleVariables` calls it and assigns `AADOAuthEndpoint`. The two public setters call that wrapper, but current AzCopy consumers and authentication code read `Get-PSFConfigValue` directly. The source search found no consumers of the mirrored variables.

Repeat the search across source, scripts, completion code, and hidden repository configuration before deletion. Check dynamic access through `Get-Variable` and `variable:` as well as literal variable names. If a real consumer exists, migrate it to the existing configuration store before removing the mirror.

Delete the two internal helpers and their setter calls. Remove the now-unused `Set-Variable` exception for `Update-PsfConfigVariables.ps1`. Retain configuration keys, defaults, persistence scopes, AzCopy path validation, auth-provider probing, and token-cache invalidation. Leave the auth cache and background jobs unchanged.

Verify that setting an AzCopy path affects the next consuming command without reimport. Check the stored value in an isolated configuration setup. Mock auth providers and verify both successful switches and failed CLI probes. Successful switches must still clear cached tokens, while failed probes must retain the previous provider.

Accept the change when the redundant module state and synchronization calls are gone, public setter contracts remain unchanged, and searches find no executable references to the removed helpers. Restore configuration after tests and never use the user's real token cache as a fixture.

## Task J: Retire the empty legacy .NET project

Own `library/d365bap.tools/`, the legacy build block in `build/vsts-build.ps1`, the commented legacy assembly entry in `d365bap.tools/d365bap.tools.psd1`, and obsolete project-specific entries in `.gitignore`. Start after E and D. Preserve E's active SDK build and generated artifacts.

The legacy project contains only an empty `Class1` and targets `net4.5.2`. Its assembly entry in the module manifest is commented out. The optional `-Build` branch in `vsts-build.ps1` points to `library/d365bap.tools.sln`, while the actual solution is under `library/d365bap.tools/`. The active Power Platform SDK project is separate under `library/PowerPlatformSdk/`.

Confirm that no tracked runtime, workflow, installer, or package step depends on the legacy type or assembly. Search hidden workflow files and inspect packaging as well as literal references. If a dependency is found, resolve it before deletion.

Remove the empty class, project, solution, obsolete manifest comment, and dedicated ignore entries. Remove the unused `-Build` switch and its old branch from the packaging script after checking repository callers. Note that build-script argument removal in the handoff. Repository workflows currently invoke packaging without that switch. Keep the unconditional `Build-PowerPlatformSdk.ps1` step and its license packaging intact.

Build from a checkout without legacy build outputs using `build/vsts-build.ps1 -SkipPublish`. Verify both source and packaged module imports, exported commands, and the SDK verifier. Inspect the package to confirm that the active SDK dependencies remain present and the empty legacy library is not required.

Accept the change when packaging has one active .NET project and no executable references to the retired library. Do not replace the obsolete switch with a second SDK build path or broaden this change into a CI rewrite.

## Task K: Consolidate application installation and operation polling

Own `d365bap.tools/functions/Invoke-PpacD365AppInstall.ps1`, `Invoke-BapEnvironmentInstallD365App.ps1`, private installation helpers, and `tests/behavior/D365AppInstallation.Tests.ps1`. Start after A, C, and D. Inspect C's helpers before adding another installation abstraction, but leave its API-specific provisioning flows unchanged.

Both commands submit installations to the same Power Platform application-package endpoint. They duplicate failed-start collection, token refresh, operation polling, timeout handling, progress reporting, and final result construction. Their main differences are the catalog getter and accepted package identifiers.

Keep catalog lookup and identifier matching in the public commands. Normalize selected packages into explicit records with the package name and fields needed for failure output. Share the install submission and operation-tracking implementation. Preserve input ordering and the first catalog match. The BAP command accepts `Id` and `UniqueName` in addition to PPAC identifiers, while the PPAC command also matches the application display name.

Preserve the distinction between an omitted `PayloadValue` and a supplied empty value. Keep the timeout start point, delay before the first poll, token refresh per polling round, and `TimeoutMinutes = 0` behavior. Preserve the active states `NotStarted` and `Running`, failure details, result properties, and existing progress and formatting output. Characterize output streams before moving presentation code.

Test complete success, mixed successful and failed starts, all starts failing, pending operations, terminal failures, timeout, and polling errors. Use a fake clock and mocked HTTP calls. Check catalog-specific matching and both payload cases through each public command. Verify that no polling occurs when no installation started and that final results retain their baseline ordering.

Accept the change when both commands use one submission and polling implementation and obsolete copies are removed. Do not introduce new retries or reuse C's package-install retry policy without a separate behavior change. No live package installation is needed for default verification.

## Task L: Consolidate Graph object resolution

Own `d365bap.tools/internal/functions/Get-GraphGroup.ps1`, `Get-GraphUser.ps1`, `Get-GraphServicePrincipal.ps1`, their replacement, direct callers, and `tests/behavior/GraphResolution.Tests.ps1`. Start after A, C, and D. Inventory callers in the public functions, including the two provisioning commands, before editing.

The three helpers repeat token acquisition, request setup, GUID detection, response handling, and zero-or-multiple-match errors. Replace them with one private resolver that takes an explicit object kind and identifier. Keep the small set of kind-specific query fields and diagnostic labels together. Migrate direct callers and remove the obsolete internal entry points in the same change.

Preserve each query's meaning. A group GUID matches `id`, while a service-principal GUID matches either `id` or `appId`. User text searches display name, principal name, and mail. Group and service-principal text searches use display name. Preserve header differences and returned object properties. Keep token acquisition in the existing `Get-BapAccessToken` boundary.

Test all object kinds with GUID and text inputs, one result, no results, multiple results, and an HTTP failure. Verify the generated filters and error propagation through representative public callers. A failed resolution must not lead to a later mutation request. Characterize the current `Stop-PSFFunction` interruption behavior before changing call depth, and report any existing continuation defect separately.

Leave `Get-GraphGroupMember.ps1` outside this migration. Its group lookup deliberately selects the first match instead of rejecting multiple matches. Preserve the existing page handling and record filter-escaping or pagination defects separately.

Accept the change when one implementation owns unique Graph-object resolution, all previous internal callers have migrated, and the public command contracts remain equivalent. Avoid turning this resolver into a general Microsoft Graph client.

## Task M: Retain the seed archive already downloaded for model removal

Own seed acquisition and archive-reading code in `d365bap.tools/functions/Remove-UdeEnvironmentModel.ps1` and `tests/behavior/ModelSeedPackages.Tests.ps1`. Start after A and D. Leave package upload, deployment, dependency expansion, and the general download helper from F outside this task.

`Get-ModelSeedPackage` downloads candidate archives to inspect `fnomoduledefinition.json`. When it finds a match, it deletes that archive and returns only the package identity. `Save-ModelSeedPackage` then downloads the same selected payload again, and `Get-ModelModuleReference` opens it again to inspect the descriptor.

Combine selection and retention into one acquisition step. Return a record containing package identity, the retained local path, and parsed module references. Inspect the definition and descriptor using a clearly owned archive lifetime. Close entry streams and the archive in `finally`. Move or copy the selected archive into the existing work-folder layout instead of downloading it again. Delete rejected temporary candidates after closing them.

Preserve the query filter, descending modification order, candidate limit, first matching definition, and supported definition shapes `Module.Name`, `Modules[0].Name`, and `Name`. Preserve missing-seed behavior and the current handling of missing or unreadable descriptors. Record concerns about treating an unreadable descriptor as no dependencies separately. Do not broaden which models can be removed.

Use small ZIP fixtures for matching, nonmatching, malformed, and missing definitions, plus descriptors with and without references. Mock package listing and payload downloads. Verify that the selected payload is downloaded once and that the exact selected bytes reach the retained path. Check rejected-file cleanup, released file handles, existing work folders, failed writes, and unchanged dependency inputs. Restrict filesystem tests to a temporary workspace.

Accept the change when the second selected-package download and superseded save helper are gone. Remove explicit garbage collection only where deterministic disposal replaces it in the touched code. The existing public removal output and deployment behavior must remain unchanged, and default tests must never submit a deletion package.

## Task N: Share CI validation and dependency setup

Own `.github/workflows/validate.yml`, `build-v2.yml`, `cache-warm.yml`, the shared validation workflow or local action, and dependency setup under `build/`. Start after D, E, and J. Coordinate any changes to `build/vsts-prerequisites.ps1` with the coordinator. Leave production commands unchanged.

The pull-request and release workflows duplicate the same general, public-analyzer, internal-analyzer, and command-test jobs. Those jobs repeat checkout, the module cache definition, and an inline module-install list. The cache-warming workflow repeats that list again, while `build/vsts-prerequisites.ps1` derives additional dependencies from the manifest.

Define the validation jobs once and invoke that definition from both workflows. Prefer a reusable workflow with the existing job boundaries. Introduce a matrix only if it reduces duplication without changing required check identities. Centralize the shared dependency inventory and setup behavior so the warm-cache job and validation jobs use the same source. Preserve the modules required specifically for build and release.

Preserve triggers, branch and path filters, runner choice, independent test groups, cache-hit behavior, and the release dependency on successful validation. Include D's behavioral tests and E's required artifact checks. Review permissions and secret access at each workflow boundary. Validation must not receive the release API key or invoke publishing.

Inspect required status checks before changing visible job names. If repository settings are unavailable, retain the existing names and report remote compatibility as unverified. Keep cache keys consistent across consumers and account for dependency changes. Avoid unrelated action-version upgrades in this refactor.

Validate the workflow structure with a YAML and Actions-aware checker when available. Run the referenced PowerShell commands locally and inspect the workflow dependency graph. Verify both cache-hit and cache-miss setup paths. Use a validation-only remote run if available, and report remote execution separately from local checks. Do not dispatch the release workflow to test this change.

Accept the change when PR and release validation share one job definition, repeated dependency lists are removed, and release remains blocked by any validation failure. Keep the shared workflow independent of publish credentials. Document any required-check mapping that still needs external verification.

## Task O: Separate security-role privilege calculation from requests

Own `d365bap.tools/functions/Set-PpacSecurityRoleTable.ps1`, one private privilege-calculation function, and `tests/behavior/SecurityRolePrivileges.Tests.ps1`. Start after A and D. Keep the public parameter declarations, configuration mappings, and `Get-PpacSecurityRoleTable.ps1` output behavior intact.

The setter currently mixes access-level translation, privilege matching, calculation of retained privileges, API action selection, request submission, and readback. The calculation depends on the table's privileges and the role's current privileges, which can be passed as ordinary data.

Move that calculation into one function with explicit inputs for requested levels, the translation map, table metadata, and current role privileges. Return the chosen action, payload, and unsupported privilege types needed for caller diagnostics. Keep configuration reads, role and table lookup, messages, HTTP requests, and final readback in the public command. The calculation must not mutate its inputs or read module state.

Preserve the existing semantics exactly. Omitted privileges default to `None`, so they remove the target table's existing assignments. A table with neither current nor desired assignments produces no request. A table with no current assignments uses `AddPrivilegesRole`. Otherwise, `ReplacePrivilegesRole` includes privileges from every other table as well as the desired target-table privileges. Keep root-role selection in the public command.

Test every access-level translation, explicit and omitted `None`, adding first assignments, replacing existing assignments, removing all target-table assignments, and unsupported privilege types. Verify that unrelated privilege IDs and depths survive unchanged. Check that the helper leaves inputs intact and that public command tests submit the expected action and payload to the root role. Cover request failure and readback as well.

Accept the change when action selection and payload calculation are independently readable and testable, with one HTTP submission path in the public command. Keep one calculation boundary rather than creating a hierarchy of single-use wrappers. Record existing permission or validation defects separately. Default tests must not modify live security roles.

## Verify each integrated change

Run commands from the repository root in PowerShell 7.6 or newer. Confirm that tests resolve the checkout module, rather than an installed release. Record pre-existing failures before changing code.

The repository currently provides these validation entry points:

```powershell
pwsh -NoProfile -File ./build/vsts-validate.ps1
pwsh -NoProfile -File ./build/vsts-validate-psscriptanalyzer.ps1
pwsh -NoProfile -File ./build/Test-PowerPlatformSdk.ps1
```

Task D adds behavioral test discovery to the first command. Until then, run the new behavioral files explicitly with Pester in an isolated test setup. Check analyzer coverage for changed files under `internal/sdk/` and `internal/scripts/`, because the dedicated analyzer runner targets public functions and `internal/functions/`.

For E and final integration, build without publishing:

```powershell
pwsh -NoProfile -File ./build/Build-PowerPlatformSdk.ps1
pwsh -NoProfile -File ./build/vsts-build.ps1 -SkipPublish
pwsh -NoProfile -File ./build/Test-PowerPlatformSdk.ps1 -ModulePath ./publish/d365bap.tools/d365bap.tools.psd1
```

Run contract and relevant behavioral checks against the packaged module as well. Use separate PowerShell processes for source and packaged verification to avoid assembly and module reuse. Check the diff for generated or binary changes and explain any that remain.

Use existing prerequisites where available. `build/vsts-prerequisites.ps1` installs the test and manifest dependencies. Help generation also requires `platyPS`. Live provisioning and maintenance writes are outside the default verification scope. Report any necessary live verification separately with its target and expected side effects.

## Return the completed work

Each agent returns a concise report with:

- Its starting commit, resulting commit, and owned files changed.
- The duplicated implementation removed and the replacement callers.
- Exact verification commands, results, and any baseline failures.
- Contract differences, deferred defects, and remaining integration work.

The coordinator verifies the combined branch after the last integration. Completion requires preserved public contracts, removal of superseded code, deterministic generation, and passing relevant checks for source and packaged artifacts. Do not claim success from compilation or signature tests alone.
