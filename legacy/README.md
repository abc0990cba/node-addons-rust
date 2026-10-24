# Legacy artifacts (not runtime)

This directory archives reference material from the old FDTD Online stack. **Nothing here is loaded by `apps/` or `packages/` at runtime.**

| Path | Contents |
|------|----------|
| `matlab/` | `refactored_pml_tf_sf.m`, `upml_tf_sf.m` — MATLAB UPML+TF/SF lineage used as a formula checklist (not ground truth) |
| `dumps/` | Numeric dumps (`Wz.txt`, etc.) and UI screenshots from the old client |
| `docs-old/` | Theory MDX stubs + old addon README |

## Correctness policy

Physics in `crates/fdtd-core` is validated against textbooks (Taflove & Hagness, Sullivan, Nikolova) and analytic tests. If MATLAB or the old C++ addon disagree with literature, literature wins — see `matlab/NOTES.md`.

Do not treat C++/`napi-addon-fdtd` as a merge gate.
