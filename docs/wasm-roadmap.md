# WASM roadmap

`fdtd-core` is intentionally free of NAPI and `wasm-bindgen`. The same crate should compile to a future `packages/fdtd-wasm` adapter.

## Plan

1. Keep hot-path APIs allocation-explicit (`Vec` behind `std`; buffers passed in for constrained targets).
2. Feature `wasm` reserved for any wasm-only shims (today unused).
3. Reuse `step_n(n)` so a browser Worker can chunk work without blocking the UI.
4. Prefer `SharedArrayBuffer` / transferable `Float64Array` views for grid dumps once binary WS frames land.
5. Grid-size limits and main-thread policy will live in the wasm package README when added — not in the core crate.

## Non-goals for v1

- No in-browser solver in this monorepo cut.
- No automatic wasm-pack CI yet.
