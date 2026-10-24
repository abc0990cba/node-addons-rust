//! Physical constants and unit conventions used by solvers.

/// Vacuum speed of light (m/s). SI solvers (2D / TFSF).
pub const C0_SI: f64 = 299_792_458.0;

/// Vacuum permittivity (F/m).
pub const EPS0_SI: f64 = 8.854_187_817e-12;

/// Vacuum permeability (H/m).
pub const MU0_SI: f64 = 1.256_637_0614e-6;

/// Impedance of free space (Ω).
pub const ETA0: f64 = 376.730_313_461;

/// Optical-unit light speed used by the 1D product UX (nm/fs).
pub const C0_NM_FS: f64 = 299.792_458;

/// Optical-unit ε₀ (e / V nm) — matches legacy 1D product units.
pub const EPS0_OPT: f64 = 55.263_495_97e-3;

/// Optical-unit μ₀ (V fs² / e nm).
pub const MU0_OPT: f64 = 2.013_354_451e-4;
