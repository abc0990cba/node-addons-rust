# fdtd-core

Pure Rust FDTD physics. No NAPI, no `wasm-bindgen`, no JS types.

- Deterministic `step()` / `step_n(n)`
- No global simulation state
- Feature flags: `std` (default), `wasm` (reserved)
- Traits for Grid / Fields / Material / Source / Boundary / Monitor — extensible toward 3D

See repo `docs/physics.md` and `docs/wasm-roadmap.md`.
