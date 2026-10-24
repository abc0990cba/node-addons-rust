# FDTD Online

Nanophotonics with FDTD — monorepo with a reusable Rust physics core, NAPI adapter, Node WebSocket server, and Vite React client.

## Layout

```
apps/web                 Vite + React 19 UI
apps/server              Express + ws (per-connection sessions)
crates/fdtd-core         Pure Rust FDTD (wasm-ready API)
packages/fdtd-native     napi-rs adapter
packages/fdtd-protocol   Shared WS types + zod
legacy/                  MATLAB, dumps, old theory (not runtime)
docs/                    physics, architecture, testing, wasm-roadmap, migration
```

## Prerequisites

- Node.js ≥ 22
- pnpm 9
- Rust stable (edition 2021; tested with 1.83+)

## Setup

```bash
pnpm install
pnpm --filter @fdtd-online/native run build
pnpm --filter @fdtd-online/protocol run build
```

## Run

```bash
# terminal 1
pnpm --filter @fdtd-online/server run dev

# terminal 2
pnpm --filter @fdtd-online/web run dev
```

- UI: http://localhost:5173  
- API docs: http://localhost:5001/docs  
- Health: http://localhost:5001/health  

## Test physics

```bash
cargo test -p fdtd-core
```

## Docs

- [physics.md](docs/physics.md)
- [architecture.md](docs/architecture.md)
- [testing.md](docs/testing.md)
- [wasm-roadmap.md](docs/wasm-roadmap.md)
- [migration.md](docs/migration.md)
