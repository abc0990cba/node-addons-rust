//! Soft / hard source waveforms.

use crate::config::{SourceConfig, SourceKind};
use crate::traits::Source;

#[derive(Debug, Clone)]
pub struct Waveform {
    pub cfg: SourceConfig,
}

impl Waveform {
    pub fn new(cfg: SourceConfig) -> Self {
        Self { cfg }
    }
}

impl Source for Waveform {
    fn value_at(&self, t: f64) -> f64 {
        let a = self.cfg.amplitude;
        match self.cfg.kind {
            SourceKind::SoftGaussianCosine => {
                let env = (-((self.cfg.t0 - t) / self.cfg.tau).powi(2)).exp();
                a * env * (self.cfg.omega * t).cos()
            }
            SourceKind::SoftSinusoid | SourceKind::PlaneWaveSin => {
                a * (self.cfg.omega * t).sin()
            }
            SourceKind::HardGaussianSin => {
                let env = (-((t - self.cfg.t0) / self.cfg.tau).powi(2)).exp();
                a * (self.cfg.omega * t).sin() * env
            }
        }
    }
}
