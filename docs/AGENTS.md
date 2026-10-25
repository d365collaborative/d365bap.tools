# Module Documentation

Do not hand-edit `*.md` files here. They are generated and owned by the regen
workflow, not by PR authors.

After adding or changing a public function, push only the function source.
CI (`validate-generated`) fails until the markdown help is refreshed; a
reviewer then adds the `accept-signature-change` label and the regen workflow
commits the refreshed `*.md` files back onto the PR branch.

Local preview only (never commit the result):
`pwsh -NoProfile -File ./build/update-docs.ps1`
