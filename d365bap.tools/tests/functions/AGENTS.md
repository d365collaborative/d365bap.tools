# Unit Tests for Public Functions

Do not hand-edit `*.Tests.ps1` files here. They are generated signature
snapshots and are regenerated in the post-merge validation checkout.

After adding or changing a public function, push only the function source.
PRs reject changes to these snapshots. The separate public signature gate
reports interface changes for maintainer acceptance. Write independently
authored regression tests in `../behavior`, where the PR gate executes them.

Local preview only (never commit the result):
`pwsh -NoProfile -File ./build/generate-parameterunittests.ps1`
