//! 2D TE_z (Ex, Ey, Hz) FDTD with conductivity PML on the perimeter.

use crate::config::{
    FieldChannel, MaterialSample, SimulationConfig, SourceConfig, SourceKind,
};
use crate::constants::{C0_SI, EPS0_SI, MU0_SI};
use crate::material::MaterialGrid;
use crate::pml::PmlProfile;
use crate::source::Waveform;
use crate::traits::{Effect, Fields, Grid, MaterialModel, Source};

#[derive(Debug, Clone)]
pub struct Solver2DConfig {
    pub nx: usize,
    pub ny: usize,
    pub pml_width: usize,
    pub sim: SimulationConfig,
    pub source: SourceConfig,
    pub materials: MaterialGrid,
    pub channel: FieldChannel,
}

impl Default for Solver2DConfig {
    fn default() -> Self {
        let nx = 220;
        let ny = 220;
        let dx = 3e-6;
        Self {
            nx,
            ny,
            pml_width: 10,
            sim: SimulationConfig::si_2d(dx, dx, 0.99),
            source: SourceConfig {
                kind: SourceKind::SoftSinusoid,
                omega: 2.0 * std::f64::consts::PI * 6e12,
                tau: 30.0 * (dx / (2.0 * C0_SI)),
                t0: 3.0 * 30.0 * (dx / (2.0 * C0_SI)),
                amplitude: 10.0,
                position_rel: [0.5, 0.5],
            },
            materials: MaterialGrid::vacuum(nx, ny),
            channel: FieldChannel::Hz,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Solver2D {
    pub cfg: Solver2DConfig,
    pub ex: Vec<f64>,
    pub ey: Vec<f64>,
    pub hz: Vec<f64>,
    /// Split Hz for PML: hzx + hzy = hz in PML region.
    hzx: Vec<f64>,
    hzy: Vec<f64>,
    ca_ex: Vec<f64>,
    cb_ex: Vec<f64>,
    ca_ey: Vec<f64>,
    cb_ey: Vec<f64>,
    da_hz: Vec<f64>,
    db_hz: Vec<f64>,
    src_i: usize,
    src_j: usize,
    waveform: Waveform,
    time_step: u64,
}

impl Solver2D {
    pub fn new(cfg: Solver2DConfig) -> Self {
        let nx = cfg.nx;
        let ny = cfg.ny;
        let n = nx * ny;
        let dt = cfg.sim.dt;
        let dx = cfg.sim.dx;
        let dy = cfg.sim.dy;
        let pml = PmlProfile::taflove(cfg.pml_width, dx, 3.0, 1e-8);

        let mut sigma_x = vec![0.0; n];
        let mut sigma_y = vec![0.0; n];
        let t = cfg.pml_width;
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

        let mut ca_ex = vec![0.0; n];
        let mut cb_ex = vec![0.0; n];
        let mut ca_ey = vec![0.0; n];
        let mut cb_ey = vec![0.0; n];
        let mut da_hz = vec![0.0; n];
        let mut db_hz = vec![0.0; n];

        for j in 0..ny {
            for i in 0..nx {
                let idx = j * nx + i;
                let mat: MaterialSample = cfg.materials.sample_at(i, j, 0);
                let eps = mat.eps_r * EPS0_SI;
                let mu = mat.mu_r * MU0_SI;
                let sig = mat.sigma + 0.5 * (sigma_x[idx] + sigma_y[idx]);

                // Lossy update coeffs (Taflove 7.8 style) with PEC outer walls.
                let outer = i == 0 || j == 0 || i + 1 == nx || j + 1 == ny;
                if outer {
                    ca_ex[idx] = 1.0;
                    cb_ex[idx] = 0.0;
                    ca_ey[idx] = 1.0;
                    cb_ey[idx] = 0.0;
                    da_hz[idx] = 1.0;
                    db_hz[idx] = 0.0;
                } else {
                    ca_ex[idx] = (1.0 - sig * dt / (2.0 * eps)) / (1.0 + sig * dt / (2.0 * eps));
                    cb_ex[idx] = (dt / (eps * dy)) / (1.0 + sig * dt / (2.0 * eps));
                    ca_ey[idx] = (1.0 - sig * dt / (2.0 * eps)) / (1.0 + sig * dt / (2.0 * eps));
                    cb_ey[idx] = (dt / (eps * dx)) / (1.0 + sig * dt / (2.0 * eps));
                    let sigm = sig * MU0_SI / EPS0_SI;
                    da_hz[idx] = (1.0 - sigm * dt / (2.0 * mu)) / (1.0 + sigm * dt / (2.0 * mu));
                    db_hz[idx] = (dt / (mu * dx)) / (1.0 + sigm * dt / (2.0 * mu));
                }
            }
        }

        let src_i = ((cfg.source.position_rel[0].clamp(0.0, 1.0) * (nx as f64 - 1.0)).floor()
            as usize)
            .min(nx - 1);
        let src_j = ((cfg.source.position_rel[1].clamp(0.0, 1.0) * (ny as f64 - 1.0)).floor()
            as usize)
            .min(ny - 1);

        Self {
            waveform: Waveform::new(cfg.source),
            cfg,
            ex: vec![0.0; n],
            ey: vec![0.0; n],
            hz: vec![0.0; n],
            hzx: vec![0.0; n],
            hzy: vec![0.0; n],
            ca_ex,
            cb_ex,
            ca_ey,
            cb_ey,
            da_hz,
            db_hz,
            src_i,
            src_j,
            time_step: 0,
        }
    }

    #[inline]
    fn idx(&self, i: usize, j: usize) -> usize {
        j * self.cfg.nx + i
    }

    pub fn field_channel(&self) -> &[f64] {
        match self.cfg.channel {
            FieldChannel::Ex => &self.ex,
            FieldChannel::Ey => &self.ey,
            FieldChannel::Energy => &self.hz, // energy assembled on demand
            _ => &self.hz,
        }
    }

    pub fn snapshot_channel(&self) -> Vec<f64> {
        match self.cfg.channel {
            FieldChannel::Energy => self
                .hz
                .iter()
                .zip(self.ex.iter())
                .zip(self.ey.iter())
                .map(|((&hz, &ex), &ey)| 0.5 * (ex * ex + ey * ey) + 0.5 * hz * hz)
                .collect(),
            _ => self.field_channel().to_vec(),
        }
    }

    pub fn min_max_channel(&self) -> (f64, f64) {
        min_max(&self.snapshot_channel())
    }

    pub fn energy_hz(&self) -> f64 {
        self.hz.iter().map(|h| h * h).sum()
    }
}

impl Grid for Solver2D {
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

impl Fields for Solver2D {
    fn time_step(&self) -> u64 {
        self.time_step
    }
}

impl Effect for Solver2D {
    fn step(&mut self) {
        let nx = self.cfg.nx;
        let ny = self.cfg.ny;

        // Ex: depends on ∂Hz/∂y
        for j in 1..ny - 1 {
            for i in 0..nx {
                let idx = self.idx(i, j);
                let idx_ym = self.idx(i, j - 1);
                self.ex[idx] = self.ca_ex[idx] * self.ex[idx]
                    + self.cb_ex[idx] * (self.hz[idx] - self.hz[idx_ym]);
            }
        }

        // Ey: depends on −∂Hz/∂x
        for j in 0..ny {
            for i in 1..nx - 1 {
                let idx = self.idx(i, j);
                let idx_xm = self.idx(i - 1, j);
                self.ey[idx] = self.ca_ey[idx] * self.ey[idx]
                    - self.cb_ey[idx] * (self.hz[idx] - self.hz[idx_xm]);
            }
        }

        // Hz update (split into x/y curls for PML bookkeeping)
        for j in 0..ny - 1 {
            for i in 0..nx - 1 {
                let idx = self.idx(i, j);
                let idx_xp = self.idx(i + 1, j);
                let idx_yp = self.idx(i, j + 1);
                let dhzx = -self.db_hz[idx] * (self.ey[idx_xp] - self.ey[idx]);
                let dhzy = self.db_hz[idx] * (self.ex[idx_yp] - self.ex[idx]);
                self.hzx[idx] = self.da_hz[idx] * self.hzx[idx] + dhzx;
                self.hzy[idx] = self.da_hz[idx] * self.hzy[idx] + dhzy;
                self.hz[idx] = self.hzx[idx] + self.hzy[idx];
            }
        }

        let t = self.time_step as f64 * self.cfg.sim.dt;
        let src = self.waveform.value_at(t);
        let sidx = self.idx(self.src_i, self.src_j);
        match self.cfg.source.kind {
            SourceKind::HardGaussianSin => {
                self.hz[sidx] = src;
                self.hzx[sidx] = src * 0.5;
                self.hzy[sidx] = src * 0.5;
            }
            _ => {
                self.hz[sidx] += src;
            }
        }

        self.time_step += 1;
    }
}

fn min_max(v: &[f64]) -> (f64, f64) {
    let mut mn = f64::INFINITY;
    let mut mx = f64::NEG_INFINITY;
    for &x in v {
        if x < mn {
            mn = x;
        }
        if x > mx {
            mx = x;
        }
    }
    if !mn.is_finite() {
        mn = 0.0;
    }
    if !mx.is_finite() {
        mx = 0.0;
    }
    (mn, mx)
}

// silence unused import in some feature builds
#[allow(dead_code)]
fn _use_material_model<T: MaterialModel>(_: &T) {}
