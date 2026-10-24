//! 2D UPML + total-field / scattered-field plane-wave injection (TE_z primary).
//!
//! Formulas follow Taflove UPML (κ≡1 stretch) and the MATLAB
//! `refactored_pml_tf_sf.m` layout (nx=220, TF box 60..160). Literature wins
//! over opaque C++ `K_a1` names — see `legacy/matlab/NOTES.md`.

use crate::config::{MaterialSample, SimulationConfig, SourceConfig, SourceKind};
use crate::constants::{C0_SI, EPS0_SI, ETA0, MU0_SI};
use crate::material::MaterialGrid;
use crate::pml::PmlProfile;
use crate::source::Waveform;
use crate::traits::{Effect, Fields, Grid, MaterialModel, Source};

#[derive(Debug, Clone)]
pub struct Solver2dTfsfConfig {
    pub nx: usize,
    pub ny: usize,
    pub upml_width: usize,
    pub tf_i0: usize,
    pub tf_i1: usize,
    pub tf_j0: usize,
    pub tf_j1: usize,
    pub sim: SimulationConfig,
    pub source: SourceConfig,
    pub materials: MaterialGrid,
}

impl Default for Solver2dTfsfConfig {
    fn default() -> Self {
        let nx = 220;
        let ny = 220;
        let area = 0.000_25; // 0.25 mm — MATLAB refactored defaults
        let dx = area / nx as f64;
        Self {
            nx,
            ny,
            upml_width: 10,
            tf_i0: 60,
            tf_i1: 160,
            tf_j0: 60,
            tf_j1: 160,
            sim: SimulationConfig::si_2d(dx, dx, 0.99),
            source: SourceConfig {
                kind: SourceKind::PlaneWaveSin,
                omega: 2.0 * std::f64::consts::PI * 20e12,
                tau: 1.0,
                t0: 0.0,
                amplitude: 1.0,
                position_rel: [0.0, 0.0],
            },
            materials: MaterialGrid::vacuum(nx, ny),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Solver2dTfsf {
    pub cfg: Solver2dTfsfConfig,
    // TE fields
    pub ex: Vec<f64>,
    pub ey: Vec<f64>,
    pub hz: Vec<f64>,
    // TM companion (product dumps both)
    pub ez: Vec<f64>,
    pub hx: Vec<f64>,
    pub hy: Vec<f64>,
    // UPML auxiliary (simplified κ=1 electric/magnetic conductivity)
    psi_exy: Vec<f64>,
    psi_eyx: Vec<f64>,
    psi_hzx: Vec<f64>,
    psi_hzy: Vec<f64>,
    // 1D auxiliary incident (TE): Hz, Ey along x
    hz_1d: Vec<f64>,
    ey_1d: Vec<f64>,
    ez_1d: Vec<f64>,
    hy_1d: Vec<f64>,
    ca: Vec<f64>,
    cb: Vec<f64>,
    da: Vec<f64>,
    db: Vec<f64>,
    sigma_x: Vec<f64>,
    sigma_y: Vec<f64>,
    waveform: Waveform,
    time_step: u64,
}

impl Solver2dTfsf {
    pub fn new(cfg: Solver2dTfsfConfig) -> Self {
        let nx = cfg.nx;
        let ny = cfg.ny;
        let n = nx * ny;
        let dt = cfg.sim.dt;
        let dx = cfg.sim.dx;
        let pml = PmlProfile::taflove(cfg.upml_width, dx, 4.0, 1e-16);

        let mut sigma_x = vec![0.0; n];
        let mut sigma_y = vec![0.0; n];
        let t = cfg.upml_width;
        for j in 0..ny {
            for i in 0..nx {
                let idx = j * nx + i;
                if i < t {
                    sigma_x[idx] = pml.sigma_at_depth((t - i) as f64);
                } else if i >= nx - t {
                    sigma_x[idx] = pml.sigma_at_depth((i - (nx - t - 1)) as f64);
                }
                if j < t {
                    sigma_y[idx] = pml.sigma_at_depth((t - j) as f64);
                } else if j >= ny - t {
                    sigma_y[idx] = pml.sigma_at_depth((j - (ny - t - 1)) as f64);
                }
            }
        }

        let mut ca = vec![0.0; n];
        let mut cb = vec![0.0; n];
        let mut da = vec![0.0; n];
        let mut db = vec![0.0; n];
        for j in 0..ny {
            for i in 0..nx {
                let idx = j * nx + i;
                let mat: MaterialSample = cfg.materials.sample_at(i, j, 0);
                let eps = mat.eps_r * EPS0_SI;
                let mu = mat.mu_r * MU0_SI;
                let sig = mat.sigma + sigma_x[idx] + sigma_y[idx];
                let outer = i == 0 || j == 0 || i + 1 == nx || j + 1 == ny;
                if outer {
                    ca[idx] = 1.0;
                    cb[idx] = 0.0;
                    da[idx] = 1.0;
                    db[idx] = 0.0;
                } else {
                    ca[idx] = (1.0 - sig * dt / (2.0 * eps)) / (1.0 + sig * dt / (2.0 * eps));
                    cb[idx] = (dt / (eps * dx)) / (1.0 + sig * dt / (2.0 * eps));
                    let sigm = sig * MU0_SI / EPS0_SI;
                    da[idx] = (1.0 - sigm * dt / (2.0 * mu)) / (1.0 + sigm * dt / (2.0 * mu));
                    db[idx] = (dt / (mu * dx)) / (1.0 + sigm * dt / (2.0 * mu));
                }
            }
        }

        let aux_len = cfg.tf_i1 + 2;
        Self {
            waveform: Waveform::new(cfg.source),
            cfg,
            ex: vec![0.0; n],
            ey: vec![0.0; n],
            hz: vec![0.0; n],
            ez: vec![0.0; n],
            hx: vec![0.0; n],
            hy: vec![0.0; n],
            psi_exy: vec![0.0; n],
            psi_eyx: vec![0.0; n],
            psi_hzx: vec![0.0; n],
            psi_hzy: vec![0.0; n],
            hz_1d: vec![0.0; aux_len],
            ey_1d: vec![0.0; aux_len],
            ez_1d: vec![0.0; aux_len],
            hy_1d: vec![0.0; aux_len],
            ca,
            cb,
            da,
            db,
            sigma_x,
            sigma_y,
            time_step: 0,
        }
    }

    #[inline]
    fn idx(&self, i: usize, j: usize) -> usize {
        j * self.cfg.nx + i
    }

    fn step_1d_incident(&mut self) {
        let t = self.time_step as f64 * self.cfg.sim.dt;
        let src = self.waveform.value_at(t);
        // Soft inject at left of 1D line
        self.hz_1d[0] += src;
        self.ez_1d[0] += src;

        let dx = self.cfg.sim.dx;
        let dt = self.cfg.sim.dt;
        let c = C0_SI;
        let ce = dt / (EPS0_SI * dx);
        let ch = dt / (MU0_SI * dx);
        let len = self.hz_1d.len();

        for i in 0..len - 1 {
            self.ey_1d[i] += -ce * (self.hz_1d[i + 1] - self.hz_1d[i]);
            self.hy_1d[i] += -ch * (self.ez_1d[i + 1] - self.ez_1d[i]);
        }
        for i in 1..len - 1 {
            self.hz_1d[i] += -ch * (self.ey_1d[i] - self.ey_1d[i - 1]);
            self.ez_1d[i] += -ce * (self.hy_1d[i] - self.hy_1d[i - 1]);
        }
        let _ = c;
        let _ = ETA0;
    }

    /// Apply TF/SF corrections on the total-field box faces (x-traveling wave).
    fn apply_tfsf_corrections(&mut self) {
        let i0 = self.cfg.tf_i0;
        let i1 = self.cfg.tf_i1.min(self.cfg.nx - 2);
        let j0 = self.cfg.tf_j0;
        let j1 = self.cfg.tf_j1.min(self.cfg.ny - 2);
        let dx = self.cfg.sim.dx;
        let dt = self.cfg.sim.dt;
        let ce = dt / (EPS0_SI * dx);
        let ch = dt / (MU0_SI * dx);

        // Left face (i = i0): correct Ey / Hz using incident
        for j in j0..=j1 {
            let idx = self.idx(i0, j);
            let inc_hz = self.hz_1d.get(i0).copied().unwrap_or(0.0);
            let inc_ey = self.ey_1d.get(i0).copied().unwrap_or(0.0);
            self.ey[idx] += ce * inc_hz;
            self.hz[idx] += ch * inc_ey;
            let inc_ez = self.ez_1d.get(i0).copied().unwrap_or(0.0);
            let inc_hy = self.hy_1d.get(i0).copied().unwrap_or(0.0);
            self.ez[idx] += ce * inc_hy;
            self.hy[idx] += ch * inc_ez;
        }
        // Right face (i = i1)
        for j in j0..=j1 {
            let idx = self.idx(i1, j);
            let inc_hz = self.hz_1d.get(i1).copied().unwrap_or(0.0);
            let inc_ey = self.ey_1d.get(i1).copied().unwrap_or(0.0);
            self.ey[idx] -= ce * inc_hz;
            self.hz[idx] -= ch * inc_ey;
            let inc_ez = self.ez_1d.get(i1).copied().unwrap_or(0.0);
            let inc_hy = self.hy_1d.get(i1).copied().unwrap_or(0.0);
            self.ez[idx] -= ce * inc_hy;
            self.hy[idx] -= ch * inc_ez;
        }
        // Bottom / top faces: corrections for Ex using incident Hz (phase = i)
        for i in i0..=i1 {
            let inc_hz = self.hz_1d.get(i).copied().unwrap_or(0.0);
            let idx_b = self.idx(i, j0);
            let idx_t = self.idx(i, j1);
            self.ex[idx_b] -= ce * inc_hz;
            self.ex[idx_t] += ce * inc_hz;
            let inc_ez = self.ez_1d.get(i).copied().unwrap_or(0.0);
            self.hx[idx_b] += ch * inc_ez;
            self.hx[idx_t] -= ch * inc_ez;
        }
    }

    pub fn min_max_ez(&self) -> (f64, f64) {
        min_max(&self.ez)
    }

    pub fn min_max_hz(&self) -> (f64, f64) {
        min_max(&self.hz)
    }

    /// Mean |Hz| outside TF box (scattered-field region) — vacuum leak metric.
    pub fn scattered_hz_rms(&self) -> f64 {
        let i0 = self.cfg.tf_i0;
        let i1 = self.cfg.tf_i1;
        let j0 = self.cfg.tf_j0;
        let j1 = self.cfg.tf_j1;
        let mut s = 0.0;
        let mut c = 0usize;
        for j in 0..self.cfg.ny {
            for i in 0..self.cfg.nx {
                let inside = i >= i0 && i <= i1 && j >= j0 && j <= j1;
                if !inside {
                    let v = self.hz[self.idx(i, j)];
                    s += v * v;
                    c += 1;
                }
            }
        }
        if c == 0 {
            0.0
        } else {
            (s / c as f64).sqrt()
        }
    }
}

impl Grid for Solver2dTfsf {
    fn nx(&self) -> usize {
        self.cfg.nx
    }
    fn ny(&self) -> usize {
        self.cfg.ny
    }
    fn dx(&self) -> f64 {
        self.cfg.sim.dx
    }
    fn dy(&self) -> f64 {
        self.cfg.sim.dy
    }
    fn dim(&self) -> u8 {
        2
    }
}

impl Fields for Solver2dTfsf {
    fn time_step(&self) -> u64 {
        self.time_step
    }
}

impl Effect for Solver2dTfsf {
    fn step(&mut self) {
        let nx = self.cfg.nx;
        let ny = self.cfg.ny;

        self.step_1d_incident();

        // TE Ex / Ey
        for j in 1..ny - 1 {
            for i in 0..nx {
                let idx = self.idx(i, j);
                let curl = self.hz[idx] - self.hz[self.idx(i, j - 1)];
                // UPML ψ (κ=1): recursive conductivity filter on curl
                let bx = (-self.sigma_y[idx] * self.cfg.sim.dt / EPS0_SI).exp();
                self.psi_exy[idx] = bx * self.psi_exy[idx] + (1.0 - bx) * curl;
                self.ex[idx] = self.ca[idx] * self.ex[idx] + self.cb[idx] * (curl + self.psi_exy[idx]);
            }
        }
        for j in 0..ny {
            for i in 1..nx - 1 {
                let idx = self.idx(i, j);
                let curl = self.hz[idx] - self.hz[self.idx(i - 1, j)];
                let bx = (-self.sigma_x[idx] * self.cfg.sim.dt / EPS0_SI).exp();
                self.psi_eyx[idx] = bx * self.psi_eyx[idx] + (1.0 - bx) * curl;
                self.ey[idx] =
                    self.ca[idx] * self.ey[idx] - self.cb[idx] * (curl + self.psi_eyx[idx]);
            }
        }

        // TE Hz
        for j in 0..ny - 1 {
            for i in 0..nx - 1 {
                let idx = self.idx(i, j);
                let curlx = self.ey[self.idx(i + 1, j)] - self.ey[idx];
                let curly = self.ex[self.idx(i, j + 1)] - self.ex[idx];
                let bx = (-self.sigma_x[idx] * self.cfg.sim.dt / EPS0_SI).exp();
                let by = (-self.sigma_y[idx] * self.cfg.sim.dt / EPS0_SI).exp();
                self.psi_hzx[idx] = bx * self.psi_hzx[idx] + (1.0 - bx) * curlx;
                self.psi_hzy[idx] = by * self.psi_hzy[idx] + (1.0 - by) * curly;
                self.hz[idx] = self.da[idx] * self.hz[idx]
                    - self.db[idx] * (curlx + self.psi_hzx[idx])
                    + self.db[idx] * (curly + self.psi_hzy[idx]);
            }
        }

        // TM Ez / Hx / Hy (same lattice, dual)
        for j in 1..ny - 1 {
            for i in 1..nx - 1 {
                let idx = self.idx(i, j);
                let curl = (self.hy[idx] - self.hy[self.idx(i - 1, j)])
                    - (self.hx[idx] - self.hx[self.idx(i, j - 1)]);
                self.ez[idx] = self.ca[idx] * self.ez[idx] + self.cb[idx] * curl;
            }
        }
        for j in 0..ny - 1 {
            for i in 0..nx {
                let idx = self.idx(i, j);
                let curl = self.ez[self.idx(i, j + 1)] - self.ez[idx];
                self.hx[idx] = self.da[idx] * self.hx[idx] - self.db[idx] * curl;
            }
        }
        for j in 0..ny {
            for i in 0..nx - 1 {
                let idx = self.idx(i, j);
                let curl = self.ez[self.idx(i + 1, j)] - self.ez[idx];
                self.hy[idx] = self.da[idx] * self.hy[idx] + self.db[idx] * curl;
            }
        }

        self.apply_tfsf_corrections();
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
