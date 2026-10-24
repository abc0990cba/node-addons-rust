//! Explicit simulation configuration — no magic constants scattered across solvers.

use crate::constants::{C0_NM_FS, C0_SI};

/// Shared time/space stepping policy.
#[derive(Debug, Clone, Copy)]
pub struct SimulationConfig {
    pub dx: f64,
    pub dy: f64,
    pub dz: f64,
    pub dt: f64,
    pub cfl: f64,
}

impl SimulationConfig {
    /// 1D optical-unit grid (nm/fs), matching the legacy product scale.
    pub fn optical_1d(dx_nm: f64, cfl: f64) -> Self {
        let dt = dx_nm * cfl / C0_NM_FS;
        Self {
            dx: dx_nm,
            dy: dx_nm,
            dz: dx_nm,
            dt,
            cfl,
        }
    }

    /// 2D SI grid with 2D CFL: `dt = cfl / (c * sqrt(1/dx² + 1/dy²))`.
    pub fn si_2d(dx: f64, dy: f64, cfl: f64) -> Self {
        let dt = cfl / (C0_SI * ((1.0 / (dx * dx)) + (1.0 / (dy * dy))).sqrt());
        Self {
            dx,
            dy,
            dz: dx,
            dt,
            cfl,
        }
    }

    pub fn assert_cfl_stable_2d(&self) {
        let limit = 1.0 / (C0_SI * ((1.0 / (self.dx * self.dx)) + (1.0 / (self.dy * self.dy))).sqrt());
        debug_assert!(
            self.dt <= limit * 1.000_001,
            "dt exceeds 2D CFL limit: {} > {}",
            self.dt,
            limit
        );
    }
}

/// Isotropic material sample (relative ε, μ + electric conductivity).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct MaterialSample {
    pub eps_r: f64,
    pub mu_r: f64,
    pub sigma: f64,
}

impl MaterialSample {
    pub const VACUUM: Self = Self {
        eps_r: 1.0,
        mu_r: 1.0,
        sigma: 0.0,
    };

    pub fn new(eps_r: f64, mu_r: f64, sigma: f64) -> Self {
        Self {
            eps_r,
            mu_r,
            sigma,
        }
    }
}

/// Source waveform kind for soft / hard injection.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SourceKind {
    /// Soft Gaussian envelope × cosine (1D product default).
    SoftGaussianCosine,
    /// Soft pure sinusoid (2D `src_type == 1`).
    SoftSinusoid,
    /// Hard Gaussian-modulated sine table (2D otherwise).
    HardGaussianSin,
    /// Soft plane-wave sinusoid for TF/SF 1D auxiliary lines.
    PlaneWaveSin,
}

#[derive(Debug, Clone, Copy)]
pub struct SourceConfig {
    pub kind: SourceKind,
    pub omega: f64,
    pub tau: f64,
    pub t0: f64,
    pub amplitude: f64,
    /// Relative position in [0, 1] along each axis used by the product UI.
    pub position_rel: [f64; 2],
}

impl Default for SourceConfig {
    fn default() -> Self {
        Self {
            kind: SourceKind::SoftGaussianCosine,
            omega: 1.5 / 0.658_211_951_4, // ~1.5 eV / ħ (legacy 1D)
            tau: 8.0,
            t0: 20.0,
            amplitude: 1.0,
            position_rel: [0.2, 0.5],
        }
    }
}

/// Which field channel to dump for visualization.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FieldChannel {
    Ex,
    Ey,
    Ez,
    Hx,
    Hy,
    Hz,
    Energy,
}

impl FieldChannel {
    pub fn from_data_return_type(v: u32) -> Self {
        match v {
            1 => Self::Ex,
            2 => Self::Ey,
            3 => Self::Energy,
            _ => Self::Hz, // 0 and unknown → Hz (legacy "Ez" misnomer fixed)
        }
    }
}
