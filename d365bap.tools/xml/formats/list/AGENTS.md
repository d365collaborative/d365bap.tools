# List format views

Create and maintain list views here. One file per type:

`<TypeName>.List.Format.ps1xml`

Do not edit `../../d365bap.tools.List.Format.ps1xml` (owned by the regen
workflow). After changing a file here, push only the per-type file; CI fails
until the consolidated file is rebuilt, then the regen workflow commits it
back onto the PR branch.

Local preview only (never commit the result):

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```
