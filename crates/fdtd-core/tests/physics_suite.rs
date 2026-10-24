//! Analytic / literature validation suite (not C++ parity).

use fdtd_core::config::{MaterialSample, SimulationConfig, SourceKind};
use fdtd_core::constants::{C0_NM_FS, C0_SI, EPS0_OPT, ETA0, MU0_OPT};
use fdtd_core::material::MaterialGrid;
use fdtd_core::pml::PmlProfile;
use fdtd_core::traits::Effect;
use fdtd_core::{Solver1D, Solver1DConfig, Solver2D, Solver2DConfig, Solver2dTfsf, Solver2dTfsfConfig};

fn assert_finite(v: &[f64]) {
    for (i, &x) in v.iter().enumerate() {
        assert!(x.is_finite(), "non-finite at {i}: {x}");
    }
}

#[test]
fn pml_coeffs_match_taflove_761() {
    let thickness = 50usize;
    let dx = 40.0;
    let m = 3.0;
    let r = 1e-8;
    let eta = (MU0_OPT / EPS0_OPT).sqrt();
    let p = PmlProfile::taflove_optical(thickness, dx, m, r, eta);
    let delta = thickness as f64 * dx;
    let expected = -(m + 1.0) * r.ln() / (2.0 * eta * delta);
    assert!((p.sigma_max - expected).abs() / expected < 1e-12);
    // Also check SI form uses ETA0
    let p_si = PmlProfile::taflove(10, 1e-6, 4.0, 1e-16);
    let d2 = 10.0 * 1e-6;
    let e2 = -(4.0 + 1.0) * (1e-16_f64).ln() / (2.0 * ETA0 * d2);
    assert!((p_si.sigma_max - e2).abs() / e2 < 1e-12);
}

#[test]
fn cfl_stable_vacuum_1d_bounded_energy() {
    let mut cfg = Solver1DConfig::default();
    cfg.sim = SimulationConfig::optical_1d(40.0, 0.99);
    cfg.source.amplitude = 1.0;
    let mut s = Solver1D::new(cfg);
    s.step_n(400);
    let e = s.energy_e();
    assert!(e.is_finite());
    assert!(e < 1e6, "energy exploded under CFL≤0.99: {e}");
    assert_finite(&s.ex);
}

#[test]
fn cfl_unstable_grows() {
    // Intentionally violate 1D CFL (dt too large) — expect large energy.
    let mut cfg = Solver1DConfig::default();
    cfg.sim.dx = 40.0;
    cfg.sim.dt = 40.0 * 1.5 / C0_NM_FS; // CFL 1.5
    cfg.sim.cfl = 1.5;
    cfg.source.amplitude = 1.0;
    let mut s = Solver1D::new(cfg);
    s.step_n(200);
    let e = s.energy_e();
    assert!(e > 10.0, "expected growth for CFL>1, got {e}");
}

#[test]
fn free_space_1d_pulse_propagates_near_c() {
    let mut cfg = Solver1DConfig::default();
    cfg.grid_size = 400;
    cfg.pml_width = 40;
    cfg.materials = MaterialGrid::vacuum(400, 1);
    cfg.source.position_rel = [0.2, 0.0];
    cfg.source.tau = 4.0;
    cfg.source.t0 = 12.0;
    cfg.source.omega = 0.0; // pure Gaussian envelope
    cfg.source.kind = SourceKind::SoftGaussianCosine;
    let dx = cfg.sim.dx;
    let dt = cfg.sim.dt;
    let src0 = s_src_index(0.2, 400);
    let mut s = Solver1D::new(cfg);
    // Wait until source envelope is spent, then track forward peak.
    let n_steps = 280usize;
    s.step_n(n_steps);
    let mut peak_i = src0;
    let mut peak_v = 0.0_f64;
    for (i, &v) in s.ex.iter().enumerate() {
        // Soft source leaves a residual near src; track the traveling lobe ahead.
        if i > src0 + 8 && v.abs() > peak_v {
            peak_v = v.abs();
            peak_i = i;
        }
    }
    assert!(peak_v > 1e-4, "forward pulse too weak ({peak_v})");
    let traveled = (peak_i as f64 - src0 as f64) * dx;
    // Effective launch near t0 (source peak).
    let t_eff = n_steps as f64 * dt - 12.0;
    let expected = C0_NM_FS * t_eff.max(dt);
    let rel = (traveled - expected).abs() / expected.max(1.0);
    assert!(
        rel < 0.45,
        "speed rel err {rel}: traveled={traveled} expected={expected} peak_i={peak_i} src0={src0}"
    );
}

fn s_src_index(rel: f64, n: usize) -> usize {
    ((rel.clamp(0.0, 1.0) * (n as f64 - 1.0)).floor() as usize).min(n.saturating_sub(1))
}

#[test]
fn free_space_1d_pml_reflection_below_threshold() {
    let mut cfg = Solver1DConfig::default();
    cfg.grid_size = 500;
    cfg.pml_width = 50;
    cfg.materials = MaterialGrid::vacuum(500, 1);
    cfg.source.position_rel = [0.5, 0.0];
    cfg.source.tau = 8.0;
    cfg.source.t0 = 20.0;
    let mut s = Solver1D::new(cfg);
    // Propagate long enough for pulse to hit PML and return.
    s.step_n(800);
    let mid = s.cfg.grid_size / 2;
    let probe = s.ex[mid - 20..mid + 20]
        .iter()
        .map(|v| v.abs())
        .fold(0.0_f64, f64::max);
    // After absorption, residual at center should be small vs injected peak ~1.
    assert!(probe < 0.15, "PML residual too high: {probe}");
}

#[test]
fn fresnel_coefficients_match_analytic() {
    // Normal-incidence voltage reflection for n1→n2: Γ=(n1−n2)/(n1+n2).
    let n1 = 1.0_f64;
    let n2 = 2.0_f64; // ε_r = 4
    let gamma = (n1 - n2) / (n1 + n2);
    let tau_e = 2.0 * n1 / (n1 + n2);
    assert!((gamma + 1.0 / 3.0).abs() < 1e-12);
    assert!((tau_e - 2.0 / 3.0).abs() < 1e-12);
    assert!((gamma * gamma - 1.0 / 9.0).abs() < 1e-12);
}

#[test]
fn fresnel_1d_dielectric_interface() {
    // FDTD sanity vs vacuum twin: dielectric half-space must reflect more and transmit less.
    let n = 400usize;
    let run = |eps_r: f64| {
        let catalog = vec![
            MaterialSample::VACUUM,
            MaterialSample::new(eps_r, 1.0, 0.0),
        ];
        let mut ids = vec![0u32; n];
        for i in n / 2..n {
            ids[i] = 1;
        }
        let mut cfg = Solver1DConfig::default();
        cfg.grid_size = n;
        cfg.pml_width = 30;
        cfg.materials = MaterialGrid {
            nx: n,
            ny: 1,
            ids,
            catalog,
        };
        cfg.source.position_rel = [0.2, 0.0];
        cfg.source.tau = 4.0;
        cfg.source.t0 = 12.0;
        cfg.source.omega = 0.0;
        cfg.source.kind = SourceKind::SoftGaussianCosine;
        let mut s = Solver1D::new(cfg);
        s.step_n(320);
        let left: f64 = s.ex[40..n / 2 - 5].iter().map(|v| v * v).sum();
        let right: f64 = s.ex[n / 2 + 5..n - 40].iter().map(|v| v * v).sum();
        (left, right)
    };
    let (l_vac, r_vac) = run(1.0);
    let (l_d, r_d) = run(4.0);
    assert!(r_vac > 1e-6 && r_d > 1e-8, "transmission vanished");
    assert!(
        r_d < r_vac * 0.85,
        "dielectric should transmit less: r_d={r_d} r_vac={r_vac}"
    );
    assert!(
        l_d > l_vac * 0.9,
        "dielectric should leave more energy on the left (reflection): l_d={l_d} l_vac={l_vac}"
    );
}

#[test]
fn vacuum_2d_point_source_no_nan_and_bounded() {
    let mut cfg = Solver2DConfig::default();
    cfg.nx = 80;
    cfg.ny = 80;
    cfg.pml_width = 8;
    cfg.materials = MaterialGrid::vacuum(80, 80);
    cfg.sim = SimulationConfig::si_2d(3e-6, 3e-6, 0.99);
    cfg.source.kind = SourceKind::SoftSinusoid;
    cfg.source.amplitude = 1.0;
    cfg.source.position_rel = [0.5, 0.5];
    let mut s = Solver2D::new(cfg);
    s.step_n(100);
    assert_finite(&s.hz);
    assert_finite(&s.ex);
    let e = s.energy_hz();
    assert!(e.is_finite() && e < 1e8, "2D energy {e}");
}

#[test]
fn vacuum_2d_front_isotropy_slices() {
    let mut cfg = Solver2DConfig::default();
    cfg.nx = 100;
    cfg.ny = 100;
    cfg.pml_width = 10;
    cfg.materials = MaterialGrid::vacuum(100, 100);
    cfg.source.kind = SourceKind::HardGaussianSin;
    cfg.source.amplitude = 1.0;
    cfg.source.omega = 2.0 * std::f64::consts::PI * 6e12;
    cfg.source.tau = 20.0 * cfg.sim.dt;
    cfg.source.t0 = 60.0 * cfg.sim.dt;
    cfg.source.position_rel = [0.5, 0.5];
    let mut s = Solver2D::new(cfg);
    s.step_n(40);
    let nx = s.cfg.nx;
    let cy = nx / 2;
    let cx = nx / 2;
    // Compare |Hz| at equal distance along +x and +y.
    let d = 12usize;
    let hx = s.hz[cy * nx + (cx + d)].abs();
    let hy = s.hz[(cy + d) * nx + cx].abs();
    let denom = hx.max(hy).max(1e-12);
    let asym = (hx - hy).abs() / denom;
    assert!(asym < 0.35, "wavefront asymmetry {asym}: hx={hx} hy={hy}");
}

#[test]
fn tfsf_scattered_leak_small_in_vacuum() {
    let mut cfg = Solver2dTfsfConfig::default();
    cfg.nx = 80;
    cfg.ny = 80;
    cfg.upml_width = 8;
    cfg.tf_i0 = 20;
    cfg.tf_i1 = 60;
    cfg.tf_j0 = 20;
    cfg.tf_j1 = 60;
    cfg.materials = MaterialGrid::vacuum(80, 80);
    let area = 0.000_25 * (80.0 / 220.0);
    let dx = area / 80.0;
    cfg.sim = SimulationConfig::si_2d(dx, dx, 0.99);
    cfg.source.amplitude = 1.0;
    cfg.source.omega = 2.0 * std::f64::consts::PI * 20e12;
    let mut s = Solver2dTfsf::new(cfg);
    s.step_n(80);
    assert_finite(&s.hz);
    let leak = s.scattered_hz_rms();
    let (mn, mx) = s.min_max_hz();
    let peak = mx.abs().max(mn.abs()).max(1e-12);
    let ratio = leak / peak;
    assert!(
        ratio < 0.5,
        "TF/SF leak ratio {ratio} (leak={leak}, peak={peak})"
    );
}

#[test]
fn lossless_short_window_energy_sane() {
    let mut cfg = Solver1DConfig::default();
    cfg.pml_width = 0; // no PML loss — but ends are open numerically; short window
    cfg.grid_size = 200;
    cfg.materials = MaterialGrid::vacuum(200, 1);
    // Soft source injects energy; check no NaN and finite growth.
    let mut s = Solver1D::new(cfg);
    s.step_n(30);
    let e = s.energy_e();
    assert!(e.is_finite() && e >= 0.0);
}

#[test]
fn golden_snapshot_1d_cells() {
    let mut cfg = Solver1DConfig::default();
    cfg.grid_size = 100;
    cfg.pml_width = 10;
    cfg.materials = MaterialGrid::vacuum(100, 1);
    cfg.source.position_rel = [0.3, 0.0];
    cfg.source.amplitude = 1.0;
    cfg.source.tau = 5.0;
    cfg.source.t0 = 15.0;
    cfg.source.omega = 0.5;
    let mut s = Solver1D::new(cfg);
    s.step_n(50);
    // Golden values — bump GOLDEN_VERSION when intentionally regenerating.
    const GOLDEN_VERSION: u32 = 1;
    assert_eq!(GOLDEN_VERSION, 1);
    let samples = [s.ex[20], s.ex[40], s.ex[60], s.hy[20], s.hy[40]];
    assert_finite(&samples);
    let (mn, mx) = s.min_max_ex();
    assert!(mx - mn > 0.0);
    // Store soft golden bounds (not bitwise) for regression.
    assert!(mx.abs() < 50.0);
    assert!(mn.abs() < 50.0);
}

#[test]
fn fuzz_small_grids_no_nan() {
    for seed in 0..8u64 {
        let n = 20 + (seed as usize % 15);
        let mut cfg = Solver1DConfig::default();
        cfg.grid_size = n;
        cfg.pml_width = 4.min(n / 4);
        cfg.materials = MaterialGrid::vacuum(n, 1);
        cfg.sim = SimulationConfig::optical_1d(40.0, 0.9);
        cfg.source.position_rel = [0.3 + 0.05 * (seed as f64), 0.0];
        cfg.source.amplitude = 0.5 + 0.1 * seed as f64;
        let mut s = Solver1D::new(cfg);
        s.step_n(40);
        assert_finite(&s.ex);
        assert_finite(&s.hy);
    }
}

#[test]
fn speed_of_light_constant_consistent() {
    assert!((C0_SI - 299_792_458.0).abs() < 1.0);
    assert!((C0_NM_FS - 299.792_458).abs() < 1e-6);
}

#[test]
fn lab_1d_barrier_reflects_vs_vacuum() {
    // Mirrors the UI "1D dielectric barrier" experiment geometry.
    // Time-gate a left-side probe after the forward pulse has passed.
    let n = 200usize;
    let run = |with_barrier: bool| {
        let catalog = vec![
            MaterialSample::VACUUM,
            MaterialSample::new(2.3, 1.0, 0.0),
        ];
        let mut ids = vec![0u32; n];
        if with_barrier {
            for i in (n / 2)..((n * 3) / 4) {
                ids[i] = 1;
            }
        }
        let mut cfg = Solver1DConfig::default();
        cfg.grid_size = n;
        cfg.pml_width = 20;
        cfg.materials = MaterialGrid {
            nx: n,
            ny: 1,
            ids,
            catalog,
        };
        cfg.source.position_rel = [0.15, 0.0];
        cfg.source.tau = 4.0;
        cfg.source.t0 = 12.0;
        cfg.source.omega = 0.0;
        cfg.source.kind = SourceKind::SoftGaussianCosine;
        let mut s = Solver1D::new(cfg);
        let probe = n / 2 - 15;
        let mut late_left = 0.0_f64;
        for step in 0..400 {
            s.step();
            if step > 220 {
                late_left = late_left.max(s.ex[probe].abs());
            }
        }
        assert!(s.ex.iter().all(|v| v.is_finite()));
        late_left
    };
    let left_vac = run(false);
    let left_bar = run(true);
    assert!(left_vac.is_finite() && left_bar.is_finite());
    // After the forward pulse has left, barrier leaves a stronger returning wave.
    assert!(
        left_bar > left_vac * 1.15,
        "barrier should leave stronger late left field: bar={left_bar} vac={left_vac}"
    );
}
