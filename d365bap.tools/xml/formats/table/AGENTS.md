# Table format views

Create and maintain table views here. One file per type:

`<TypeName>.Table.Format.ps1xml`

Do not edit `../../d365bap.tools.Table.Format.ps1xml` (owned by the regen
workflow). After changing a file here, push only the per-type file; CI fails
until the consolidated file is rebuilt, then the regen workflow commits it
back onto the PR branch.

Local preview only (never commit the result):

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```
