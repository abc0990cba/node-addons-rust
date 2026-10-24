//! 1D Ex/Hy FDTD with lossy PML ends (Taflove update + σ grading).

use crate::config::{MaterialSample, SimulationConfig, SourceConfig, SourceKind};
use crate::constants::{EPS0_OPT, ETA0, MU0_OPT};
use crate::material::MaterialGrid;
use crate::pml::PmlProfile;
use crate::source::Waveform;
use crate::traits::{Effect, Fields, Grid, MaterialModel, Source};

#[derive(Debug, Clone)]
pub struct Solver1DConfig {
    pub grid_size: usize,
    pub pml_width: usize,
    pub sim: SimulationConfig,
    pub source: SourceConfig,
    pub materials: MaterialGrid,
}

impl Default for Solver1DConfig {
    fn default() -> Self {
        Self {
            grid_size: 500,
            pml_width: 50,
            sim: SimulationConfig::optical_1d(40.0, 0.99),
            source: SourceConfig {
                kind: SourceKind::SoftGaussianCosine,
                omega: 1.5 / 0.658_211_951_4,
                tau: 8.0,
                t0: 20.0,
                amplitude: 1.0,
                position_rel: [0.2, 0.0],
            },
            materials: MaterialGrid::vacuum(500, 1),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Solver1D {
    pub cfg: Solver1DConfig,
    pub ex: Vec<f64>,
    pub hy: Vec<f64>,
    a: Vec<f64>,
    b: Vec<f64>,
    c: Vec<f64>,
    d: Vec<f64>,
    src_i: usize,
    waveform: Waveform,
    time_step: u64,
}

impl Solver1D {
    pub fn new(cfg: Solver1DConfig) -> Self {
        let n = cfg.grid_size;
        let eta = (MU0_OPT / EPS0_OPT).sqrt();
        let pml = PmlProfile::taflove_optical(cfg.pml_width, cfg.sim.dx, 3.0, 1e-8, eta);
        // Cross-check σ_max vs ETA0 optical; product used custom η from ε₀/μ₀.
        let _ = ETA0;

        let mut sigma = pml.grade_1d_ends(n);
        let mut eps = vec![EPS0_OPT; n];
        let mut mu = vec![MU0_OPT; n];

        for i in 0..n {
            let m: MaterialSample = cfg.materials.sample_at(i, 0, 0);
            eps[i] = m.eps_r * EPS0_OPT;
            mu[i] = m.mu_r * MU0_OPT;
            // Interior conductivity from material; PML overwrites ends.
            if i >= cfg.pml_width && i < n.saturating_sub(cfg.pml_width) {
                sigma[i] = m.sigma;
            } else if m.sigma > sigma[i] {
                sigma[i] = m.sigma;
            }
        }

        let dt = cfg.sim.dt;
        let dx = cfg.sim.dx;
        let mut a = vec![0.0; n];
        let mut b = vec![0.0; n];
        let mut c = vec![0.0; n];
        let mut d = vec![0.0; n];

        for i in 0..n {
            let sigma_star = sigma[i] * MU0_OPT / EPS0_OPT;
            a[i] = (mu[i] - 0.5 * dt * sigma_star) / (mu[i] + 0.5 * dt * sigma_star);
            b[i] = (dt / dx) / (mu[i] + 0.5 * dt * sigma_star);
            c[i] = (eps[i] - 0.5 * dt * sigma[i]) / (eps[i] + 0.5 * dt * sigma[i]);
            d[i] = (dt / dx) / (eps[i] + 0.5 * dt * sigma[i]);
        }

        let src_i = ((cfg.source.position_rel[0].clamp(0.0, 1.0) * (n as f64 - 1.0)).floor()
            as usize)
            .min(n.saturating_sub(1));

        Self {
            waveform: Waveform::new(cfg.source),
            cfg,
            ex: vec![0.0; n],
            hy: vec![0.0; n],
            a,
            b,
            c,
            d,
            src_i,
            time_step: 0,
        }
    }

    pub fn grid_size(&self) -> usize {
        self.cfg.grid_size
    }

    pub fn src_index(&self) -> usize {
        self.src_i
    }

    pub fn snapshot_ex_hy(&self) -> (Vec<f64>, Vec<f64>, Vec<f64>) {
        let n = self.cfg.grid_size;
        let x: Vec<f64> = (0..n).map(|i| i as f64).collect();
        (x, self.ex.clone(), self.hy.clone())
    }

    pub fn min_max_ex(&self) -> (f64, f64) {
        min_max(&self.ex)
    }

    pub fn min_max_hy(&self) -> (f64, f64) {
        min_max(&self.hy)
    }

    pub fn energy_e(&self) -> f64 {
        self.ex.iter().map(|e| e * e).sum()
    }
}

impl Grid for Solver1D {
    fn nx(&self) -> usize {
        self.cfg.grid_size
    }
    fn dx(&self) -> f64 {
        self.cfg.sim.dx
    }
    fn dim(&self) -> u8 {
        1
    }
}

impl Fields for Solver1D {
    fn time_step(&self) -> u64 {
        self.time_step
    }
}

impl Effect for Solver1D {
    fn step(&mut self) {
        let n = self.cfg.grid_size;
        let t = self.time_step as f64 * self.cfg.sim.dt;
        self.ex[self.src_i] += self.waveform.value_at(t);

        for i in 0..n - 1 {
            self.hy[i] = self.a[i] * self.hy[i] - self.b[i] * (self.ex[i + 1] - self.ex[i]);
        }
        for i in 1..n - 1 {
            self.ex[i] = self.c[i] * self.ex[i] - self.d[i] * (self.hy[i] - self.hy[i - 1]);
        }
        self.time_step += 1;
    }
}

fn min_max(v: &[f64]) -> (f64, f64) {
    let mut mn = f64::INFINITY;
    let mut mx = f64::NEG_INFINITY;
    for &x in v {
        mn = mn.min(x);
        mx = mx.max(x);
    }
    if !mn.is_finite() {
        mn = 0.0;
    }
    if !mx.is_finite() {
        mx = 0.0;
    }
    (mn, mx)
}
