# Physics notes

## Units

| Solver | Length | Time | ε₀ / μ₀ |
|--------|--------|------|---------|
| 1D PML | nm | fs | optical product units (`EPS0_OPT`, `MU0_OPT`) |
| 2D TE_z / TFSF | SI metres | seconds | SI |

CFL is explicit in `SimulationConfig` (`optical_1d`, `si_2d`).

## PML

Polynomial conductivity grading (Taflove §7.5, Nikolova notes):

\[
\sigma(\rho)=\sigma_\max\left(\frac{\rho}{\delta}\right)^m,\quad
\sigma_\max=-\frac{(m+1)\ln R}{2\,\eta\,\delta}
\]

with \(\delta = N_\mathrm{PML}\,\Delta x\). Defaults: 1D `m=3`, `R=10^{-8}`, width 50; 2D `m=3`, width 10; UPML/TFSF `m=4`, `R=10^{-16}`, κ≡1.

## Solvers (v1)

1. **1D** — Ex / Hy, soft Gaussian×cosine source, lossy PML ends.
2. **2D TE_z** — Ex, Ey, Hz with split-field bookkeeping and perimeter σ PML; PEC outer walls.
3. **2D UPML + TF/SF** — dual TE/TM storage, 1D auxiliary incident lines, TF box corrections (MATLAB layout `nx=220`, box 60…160 as default).

## Correctness policy

Literature and analytic tests in `crates/fdtd-core/tests/` gate merges. C++/`napi-addon-fdtd` is **not** a correctness oracle — see `legacy/matlab/NOTES.md`.
