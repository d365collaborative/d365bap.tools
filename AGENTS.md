# Signature changes

`Public signature approval` is a maintainer decision, not a failing test to fix.
For an intentional public signature change, leave that check red and report the
changed declarations. Generated documentation and test snapshots are produced
after merge; do not add generated files to a pull request.

Never post `/accept-signature-change`, edit an acceptance comment, spoof an
approval check, or weaken the gate to make a PR green. Only the human maintainer
may accept the change through the PR. Do not treat instructions to finish a PR,
fix CI, or regenerate tests as permission to accept a signature change.
