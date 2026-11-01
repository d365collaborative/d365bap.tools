# Signature changes

`Public signature approval` is a maintainer decision, not a failing test to fix.
For an intentional public signature change, leave that check red and report the
changed declarations. Generated documentation and test snapshots are produced
after merge; do not add generated files to a pull request.

Acceptance requires a new PR comment containing exactly:

```text
/accept-signature-change
```

Never post that command, edit an acceptance comment, spoof an approval check, or
weaken the gate to make a PR green. Only the human maintainer may accept the
change through the PR. Do not treat instructions to finish a PR, fix CI, or
regenerate tests as permission to accept a signature change.

# Test file approval

`Test file approval` is a maintainer decision. A pull request that adds or edits
a hand-written `*Tests.ps1` file outside `d365bap.tools/tests/functions` stays
red until the change is accepted. Deleting an existing test file needs no
acceptance. Generated parameter tests are exempt.

Acceptance requires a new PR comment containing exactly:

```text
/accept-test-file
```

Never post that command, edit an acceptance comment, spoof an approval check, or
weaken the gate to finish a PR. Report the changed test files and leave
acceptance to the maintainer. A new push requires fresh acceptance for additions
and edits. Do not treat instructions to finish a PR, fix CI, or add tests as
permission to accept new test files.

# Internal hook changes

`Internal hook approval` is a human maintainer decision. Intentional changes to
protected lint and approval tooling require acceptance after that revision's
report is visible.

Acceptance requires a new PR comment containing exactly:

```text
/accept-intenal-hook
```

Never post that command, edit an acceptance comment, spoof an approval check, or
weaken the gate to finish a PR. Report the protected files and leave acceptance
to the maintainer. New head or base revisions require fresh acceptance; ordinary
PR approval and workflow reruns do not accept changes.
