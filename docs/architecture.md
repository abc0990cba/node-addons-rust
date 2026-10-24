# Architecture

```
apps/web  --WS/JSON-->  apps/server  -->  packages/fdtd-native (NAPI)
                                              |
                                              v
                                        crates/fdtd-core
```

## Crates / packages

| Path | Role |
|------|------|
| `crates/fdtd-core` | Pure Rust FDTD: traits, PML, Solver1D / Solver2D / Solver2dTfsf. No NAPI/WASM glue. |
| `packages/fdtd-native` | Thin napi-rs adapter: `Fdtd1D`, `Fdtd2D`, `Fdtd2DTFSF`. |
| `packages/fdtd-protocol` | Zod schemas + shared WS types. |
| `apps/server` | Express + `ws`, **one `SimSession` per socket**, `/health`, `/docs`. |
| `apps/web` | Vite + React 19 client (matrix editor, HeatMap / PlotLine, WS controls). |
| `legacy/` | MATLAB, dumps, old theory MDX — not runtime. |

## Core contracts

- No global simulation state — each solver instance owns buffers.
- Deterministic `step()` / `step_n(n)` (via `Effect` trait).
- Feature flags: `std` (default), `wasm` (reserved).
- Extensibility traits: `Grid`, `Fields`, `MaterialModel`, `Source`, `Boundary`, `Monitor`.

## Field naming

Protocol and NAPI use `hz` / `ex` / `ey` (and `ez` for TFSF). Legacy `dataEz` holding Hz is not reproduced.
