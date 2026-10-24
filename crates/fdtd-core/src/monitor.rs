//! Monitors / probes. v1: full-grid dump helpers; DFT slots reserved for later.

use crate::traits::Monitor;

/// Placeholder DFT monitor slot (docs / API only in v1).
#[derive(Debug, Default)]
pub struct DftMonitorStub {
    pub frequencies_hz: Vec<f64>,
}

impl Monitor for DftMonitorStub {
    fn on_step(&mut self, _step: u64) {}
}

/// Simple min/max tracker over a scalar field.
#[derive(Debug, Default, Clone)]
pub struct MinMaxMonitor {
    pub min: f64,
    pub max: f64,
}

impl MinMaxMonitor {
    pub fn update(&mut self, field: &[f64]) {
        for &v in field {
            self.min = self.min.min(v);
            self.max = self.max.max(v);
        }
    }
}
