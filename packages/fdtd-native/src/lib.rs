#![deny(clippy::all)]

use fdtd_core::config::{
    FieldChannel, MaterialSample, SimulationConfig, SourceConfig, SourceKind,
};
use fdtd_core::material::MaterialGrid;
use fdtd_core::traits::Effect;
use fdtd_core::{
    Solver1D, Solver1DConfig, Solver2D, Solver2DConfig, Solver2dTfsf, Solver2dTfsfConfig,
};
use napi_derive::napi;

fn materials_from_js(
    material_vector: Vec<u32>,
    eps: Vec<f64>,
    mu: Vec<f64>,
    sigma: Vec<f64>,
    nx: usize,
    ny: usize,
) -> MaterialGrid {
    let catalog: Vec<MaterialSample> = (0..eps.len().max(mu.len()).max(sigma.len()).max(1))
        .map(|i| {
            MaterialSample::new(
                *eps.get(i).unwrap_or(&1.0),
                *mu.get(i).unwrap_or(&1.0),
                *sigma.get(i).unwrap_or(&0.0),
            )
        })
        .collect();
    if ny <= 1 {
        MaterialGrid::from_vector_1d(&material_vector, catalog, nx)
    } else {
        // Prefer square reshape; if length is not square, treat as row-major ny×nx coarse grid.
        let len = material_vector.len().max(1);
        let side = (len as f64).sqrt().round() as usize;
        let (src_ny, src_nx) = if side * side == len {
            (side.max(1), side.max(1))
        } else {
            // fall back: single-row stretch or best-effort height
            let h = ((len as f64) / (nx as f64)).round().max(1.0) as usize;
            let w = (len / h).max(1);
            (h, w)
        };
        let mut matrix = Vec::with_capacity(src_ny);
        for r in 0..src_ny {
            let mut row = Vec::with_capacity(src_nx);
            for c in 0..src_nx {
                row.push(
                    material_vector
                        .get(r * src_nx + c)
                        .copied()
                        .unwrap_or(0),
                );
            }
            matrix.push(row);
        }
        MaterialGrid::from_matrix(&matrix, catalog, nx, ny)
    }
}

#[napi(object)]
pub struct Fdtd1dOptions {
    pub omega: f64,
    pub tau: f64,
    pub is_reload: Option<bool>,
    pub material_vector: Vec<u32>,
    pub eps: Vec<f64>,
    pub mu: Vec<f64>,
    pub sigma: Vec<f64>,
    pub src_position: Vec<f64>,
}

#[napi(object)]
pub struct Fdtd1dOutput {
    pub data_x: Vec<f64>,
    pub data_ex: Vec<f64>,
    pub data_hy: Vec<f64>,
    pub col: u32,
    pub current_tick: u32,
    pub max_ex: f64,
    pub min_ex: f64,
    pub max_hy: f64,
    pub min_hy: f64,
}

#[napi]
pub struct Fdtd1D {
    inner: Solver1D,
}

#[napi]
impl Fdtd1D {
    #[napi(constructor)]
    pub fn new(opts: Fdtd1dOptions) -> Self {
        let grid_size = 500usize;
        let materials = materials_from_js(
            opts.material_vector,
            opts.eps,
            opts.mu,
            opts.sigma,
            grid_size,
            1,
        );
        let rel = opts.src_position.first().copied().unwrap_or(0.2);
        let mut cfg = Solver1DConfig::default();
        cfg.grid_size = grid_size;
        cfg.materials = materials;
        cfg.source = SourceConfig {
            kind: SourceKind::SoftGaussianCosine,
            omega: opts.omega,
            tau: opts.tau,
            t0: 20.0,
            amplitude: 1.0,
            position_rel: [rel, 0.0],
        };
        let _ = opts.is_reload;
        Self {
            inner: Solver1D::new(cfg),
        }
    }

    #[napi]
    pub fn get_next_time_layer(&mut self) -> Fdtd1dOutput {
        self.inner.step();
        let (x, ex, hy) = self.inner.snapshot_ex_hy();
        let (min_ex, max_ex) = self.inner.min_max_ex();
        let (min_hy, max_hy) = self.inner.min_max_hy();
        Fdtd1dOutput {
            data_x: x,
            data_ex: ex,
            data_hy: hy,
            col: self.inner.grid_size() as u32,
            current_tick: self.inner.time_step() as u32,
            max_ex,
            min_ex,
            max_hy,
            min_hy,
        }
    }
}

#[napi(object)]
pub struct Fdtd2dOptions {
    pub lambda: f64,
    pub beamsize: f64,
    pub is_reload: Option<bool>,
    pub material_vector: Vec<u32>,
    pub eps: Vec<f64>,
    pub mu: Vec<f64>,
    pub sigma: Vec<f64>,
    pub data_return_type: u32,
    pub src_position: Vec<f64>,
    pub src_type: u32,
}

#[napi(object)]
pub struct Fdtd2dOutput {
    pub data_x: Vec<f64>,
    pub data_y: Vec<f64>,
    pub rows: u32,
    pub cols: u32,
    /// Correctly named Hz (legacy clients used misnamed `dataEz`).
    pub hz: Vec<f64>,
    pub ex: Vec<f64>,
    pub ey: Vec<f64>,
    pub field: Vec<f64>,
    pub max: f64,
    pub min: f64,
    pub time_step: u32,
}

#[napi]
pub struct Fdtd2D {
    inner: Solver2D,
}

#[napi]
impl Fdtd2D {
    #[napi(constructor)]
    pub fn new(opts: Fdtd2dOptions) -> Self {
        let nx = 220usize;
        let ny = 220usize;
        let materials = materials_from_js(
            opts.material_vector,
            opts.eps,
            opts.mu,
            opts.sigma,
            nx,
            ny,
        );
        let rx = opts.src_position.first().copied().unwrap_or(0.5);
        let ry = opts.src_position.get(1).copied().unwrap_or(0.5);
        let kind = if opts.src_type == 1 {
            SourceKind::SoftSinusoid
        } else {
            SourceKind::HardGaussianSin
        };
        // lambda (µm-ish UI) → frequency; beamsize → tau scale
        let lambda_m = if opts.lambda > 1.0 {
            opts.lambda * 1e-6
        } else {
            opts.lambda.max(1e-9)
        };
        let freq = C0_SI_LOCAL / lambda_m;
        let mut cfg = Solver2DConfig::default();
        cfg.nx = nx;
        cfg.ny = ny;
        cfg.materials = materials;
        cfg.channel = FieldChannel::from_data_return_type(opts.data_return_type);
        cfg.source = SourceConfig {
            kind,
            omega: 2.0 * std::f64::consts::PI * freq,
            tau: opts.beamsize.max(1.0) * cfg.sim.dt,
            t0: 3.0 * opts.beamsize.max(1.0) * cfg.sim.dt,
            amplitude: 10.0,
            position_rel: [rx, ry],
        };
        let _ = opts.is_reload;
        Self {
            inner: Solver2D::new(cfg),
        }
    }

    #[napi]
    pub fn get_next_time_layer(&mut self) -> Fdtd2dOutput {
        self.inner.step();
        let nx = self.inner.cfg.nx;
        let ny = self.inner.cfg.ny;
        let data_x: Vec<f64> = (0..nx).map(|i| i as f64).collect();
        let data_y: Vec<f64> = (0..ny).map(|j| j as f64).collect();
        let field = self.inner.snapshot_channel();
        let (min, max) = self.inner.min_max_channel();
        Fdtd2dOutput {
            data_x,
            data_y,
            rows: ny as u32,
            cols: nx as u32,
            hz: self.inner.hz.clone(),
            ex: self.inner.ex.clone(),
            ey: self.inner.ey.clone(),
            field,
            max,
            min,
            time_step: self.inner.time_step() as u32,
        }
    }
}

const C0_SI_LOCAL: f64 = 299_792_458.0;

#[napi(object)]
pub struct Fdtd2dTfsfOptions {
    pub material_vector: Option<Vec<u32>>,
    pub eps: Option<Vec<f64>>,
    pub mu: Option<Vec<f64>>,
    pub sigma: Option<Vec<f64>>,
    pub frequency: Option<f64>,
}

#[napi(object)]
pub struct Fdtd2dTfsfOutput {
    pub data_x: Vec<f64>,
    pub data_y: Vec<f64>,
    pub rows: u32,
    pub cols: u32,
    pub ez: Vec<f64>,
    pub hz: Vec<f64>,
    pub time_step: u32,
    pub max: f64,
    pub min: f64,
    pub max_hz: f64,
    pub min_hz: f64,
}

#[napi(js_name = "Fdtd2DTFSF")]
pub struct Fdtd2DTFSF {
    inner: Solver2dTfsf,
}

#[napi]
impl Fdtd2DTFSF {
    #[napi(constructor)]
    pub fn new(opts: Option<Fdtd2dTfsfOptions>) -> Self {
        let mut cfg = Solver2dTfsfConfig::default();
        if let Some(o) = opts {
            if let (Some(mv), Some(eps), Some(mu), Some(sigma)) =
                (o.material_vector, o.eps, o.mu, o.sigma)
            {
                cfg.materials = materials_from_js(mv, eps, mu, sigma, cfg.nx, cfg.ny);
            }
            if let Some(f) = o.frequency {
                cfg.source.omega = 2.0 * std::f64::consts::PI * f;
            }
        }
        Self {
            inner: Solver2dTfsf::new(cfg),
        }
    }

    #[napi]
    pub fn get_next_time_layer(&mut self) -> Fdtd2dTfsfOutput {
        self.inner.step();
        let nx = self.inner.cfg.nx;
        let ny = self.inner.cfg.ny;
        let (min, max) = self.inner.min_max_ez();
        let (min_hz, max_hz) = self.inner.min_max_hz();
        Fdtd2dTfsfOutput {
            data_x: (0..nx).map(|i| i as f64).collect(),
            data_y: (0..ny).map(|j| j as f64).collect(),
            rows: ny as u32,
            cols: nx as u32,
            ez: self.inner.ez.clone(),
            hz: self.inner.hz.clone(),
            time_step: self.inner.time_step() as u32,
            max,
            min,
            max_hz,
            min_hz,
        }
    }
}

// Use Fields::time_step via inherent access — expose helpers on solvers.
trait TimeStepExt {
    fn time_step(&self) -> u64;
}
impl TimeStepExt for Solver1D {
    fn time_step(&self) -> u64 {
        fdtd_core::traits::Fields::time_step(self)
    }
}
impl TimeStepExt for Solver2D {
    fn time_step(&self) -> u64 {
        fdtd_core::traits::Fields::time_step(self)
    }
}
impl TimeStepExt for Solver2dTfsf {
    fn time_step(&self) -> u64 {
        fdtd_core::traits::Fields::time_step(self)
    }
}

#[allow(dead_code)]
fn _keep_sim_config() {
    let _ = SimulationConfig::optical_1d(40.0, 0.99);
}
