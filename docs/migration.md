# Migration from the old three-repo stack

| Old | New |
|-----|-----|
| `napi-addon-fdtd` (C++) | `crates/fdtd-core` + `packages/fdtd-native` |
| `fdtd-online-server` | `apps/server` |
| `fdtd-online-client` (Next 12) | `apps/web` (Vite + React 19) |

## Behavioural changes

- Physics rewritten and validated; not a blind C++ port.
- One session per WebSocket (old server used process-global interval state).
- Field keys normalized (`hz` not misnamed `dataEz`).
- TFSF accepts materials/frequency via options (old ctor ignored JS config).
- Theory MDX archived under `legacy/docs-old/`; product docs under `docs/`.

## Cutover

After this monorepo is the source of truth, archive the three GitHub repos with a README pointer here.
