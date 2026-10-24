//! Extensibility seams for 1D → 2D → 3D and new effects.
//!
//! Hot paths may monomorphize concrete solvers; these traits define the
//! configuration / plugin boundaries so 3D and dispersion land as modules,
//! not forks.

use crate::config::MaterialSample;

/// Yee lattice geometry and indexing.
pub trait Grid {
    fn nx(&self) -> usize;
    fn ny(&self) -> usize {
        1
    }
    fn nz(&self) -> usize {
        1
    }
    fn dx(&self) -> f64;
    fn dy(&self) -> f64 {
        self.dx()
    }
    fn dz(&self) -> f64 {
        self.dx()
    }
    fn dim(&self) -> u8;
}

/// Field storage access (read-only snapshot for monitors).
pub trait Fields {
    fn time_step(&self) -> u64;
}

/// Material lookup by cell.
pub trait MaterialModel {
    fn sample_at(&self, ix: usize, iy: usize, iz: usize) -> MaterialSample;
}

/// Source injection at a given time.
pub trait Source {
    fn value_at(&self, t: f64) -> f64;
}

/// Absorbing / reflecting boundary contribution (PML / UPML / future Mur).
pub trait Boundary {
    fn name(&self) -> &'static str;
}

/// Monitor / probe hook for viz and tests.
pub trait Monitor {
    fn on_step(&mut self, step: u64);
}

/// One FDTD time update.
pub trait Effect {
    fn step(&mut self);
    fn step_n(&mut self, n: usize) {
        for _ in 0..n {
            self.step();
        }
    }
}
