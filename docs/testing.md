# Testing

## Physics (`crates/fdtd-core`)

```bash
cargo test -p fdtd-core
```

Coverage (see `tests/physics_suite.rs`):

1. CFL stability / intentional instability
2. Free-space 1D pulse speed (~c)
3. 1D PML residual after absorption
4. Fresnel analytic Γ + FDTD dielectric vs vacuum
5. PML σ_max vs Taflove 7.61
6. 2D vacuum bounded / isotropy slices
7. TF/SF scattered-field leak ratio
8. Golden soft snapshot bounds
9. Small-grid fuzz (no NaN/Inf)

C++ parity is optional / ignored — not a merge gate.

## Native

```bash
pnpm --filter @fdtd-online/native run build
pnpm --filter @fdtd-online/native run test
```

## Protocol binary frames

```bash
pnpm --filter @fdtd-online/protocol run build
pnpm --filter @fdtd-online/protocol run test
```

## Manual E2E / lab demos

1. `pnpm --filter @fdtd-online/server run dev`
2. `pnpm --filter @fdtd-online/web run dev`
3. Open the Vite URL. Exercise each **Experiment** preset:
   - 1D free space / dielectric barrier (ε overlay on plot)
   - 2D point source / waveguide / diffraction / interface + line detector
   - 2D TF/SF plane wave
4. Pause / Continue / Stop; edit ε/μ/σ and re-Start.
5. Compare qualitative look to `legacy/dumps/screenshots/`.
6. Confirm WS payloads are binary by default (`frameFormat: "json"` for JSON fallback).
