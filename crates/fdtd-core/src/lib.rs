//! Pure FDTD physics kernel — NAPI / WASM adapters stay outside this crate.
//!
//! Contract: each solver owns its state; call `step()` / `step_n(n)` for a
//! deterministic advance. No process-global simulation state.

#![cfg_attr(not(feature = "std"), no_std)]

#[cfg(feature = "std")]
extern crate std;

pub mod config;
pub mod constants;
pub mod material;
pub mod monitor;
pub mod pml;
pub mod source;
pub mod traits;

#[cfg(feature = "std")]
pub mod solver1d;
#[cfg(feature = "std")]
pub mod solver2d;
#[cfg(feature = "std")]
pub mod solver2d_tfsf;

pub use config::{
    FieldChannel, MaterialSample, SimulationConfig, SourceConfig, SourceKind,
};
pub use constants::{C0_NM_FS, C0_SI, EPS0_OPT, EPS0_SI, ETA0, MU0_OPT, MU0_SI};
pub use material::MaterialGrid;
pub use pml::PmlProfile;
pub use traits::{Boundary, Effect, Fields, Grid, MaterialModel, Monitor, Source};

#[cfg(feature = "std")]
pub use solver1d::{Solver1D, Solver1DConfig};
#[cfg(feature = "std")]
pub use solver2d::{Solver2D, Solver2DConfig};
#[cfg(feature = "std")]
pub use solver2d_tfsf::{Solver2dTfsf, Solver2dTfsfConfig};
