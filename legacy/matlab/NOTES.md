# MATLAB / C++ discrepancy notes

Validated against Taflove & Hagness (PML σ grading) and standard CFL.

| Topic | Observation | Resolution in `fdtd-core` |
|-------|-------------|---------------------------|
| σ_max | Taflove 7.61: `σ_max = −(m+1) ln(R) / (2 η δ)` with δ = `pml_width * dx` | Used for 1D and 2D PML grading |
| C++ `dataEz` | 2D PML returns Hz under key `dataEz` | Protocol uses `hz` / `ex` / `ey` |
| TFSF `K_a1` / hard-coded mats | C++ TFSF ignored JS materials; opaque coefficient names | Config-driven materials; UPML coeffs from κ≡1 stretch formulas |
| `src_type` conflict | Header comments vs runtime branch disagreed | Soft sinusoid vs hard Gaussian-modulated sine documented in protocol |
| MATLAB 1-based index | `mmm=1` offsets throughout | 0-based Rust grids |

Regenerate golden snapshots only with an intentional version bump in tests.
