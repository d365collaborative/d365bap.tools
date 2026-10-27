# Module Documentation

Do not hand-edit generated `*.md` files here. This directory is a historical
snapshot; CI generates current documentation after merge and publishes it to
the repository wiki.

After adding or changing a public function, push only the function source.
PRs reject generated documentation changes. No regeneration commit is pushed
back to the PR branch.

Local preview only (never commit the result):
`pwsh -NoProfile -File ./build/update-docs.ps1`
