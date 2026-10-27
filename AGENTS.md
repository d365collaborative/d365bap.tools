# Signature changes

`Public signature approval` is a maintainer decision, not a failing test to fix.
For an intentional public signature change, leave that check red and report the
changed declarations. Generated documentation and test snapshots are produced
after merge; do not add generated files to a pull request.

Never post `/accept-signature-change`, edit an acceptance comment, spoof an
approval check, or weaken the gate to make a PR green. Only the human maintainer
may accept the change through the PR. Do not treat instructions to finish a PR,
fix CI, or regenerate tests as permission to accept a signature change.

# Internal hook changes

`Internal hook approval` is a human maintainer decision. Intentional changes
to protected lint and approval tooling require a new PR comment containing
exactly `/accept-intenal-hook` after that revision's report is visible.

Never post that command, edit an acceptance comment, spoof the approval check,
or weaken the gate to finish a PR. Report the protected files and leave
acceptance to the maintainer. New head or base revisions require fresh
acceptance; ordinary PR approval and workflow reruns do not accept changes.
