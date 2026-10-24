//! PML conductivity grading (Taflove / Nikolova).

use crate::constants::ETA0;

/// Polynomial σ profile for a PML of `thickness` cells.
///
/// Taflove §7.5 / eq. 7.60–7.61:
/// `σ(ρ) = σ_max (ρ/δ)^m`,
/// `σ_max = −(m+1) ln(R) / (2 η δ)` with `δ = thickness * dx`.
#[derive(Debug, Clone, Copy)]
pub struct PmlProfile {
    pub thickness: usize,
    pub m: f64,
    pub r_desired: f64,
    pub sigma_max: f64,
}

impl PmlProfile {
    pub fn taflove(thickness: usize, dx: f64, m: f64, r_desired: f64) -> Self {
        let delta = thickness as f64 * dx;
        let sigma_max = -(m + 1.0) * r_desired.ln() / (2.0 * ETA0 * delta);
        Self {
            thickness,
            m,
            r_desired,
            sigma_max,
        }
    }

    /// Optical-unit η₀ from ε₀/μ₀ product units.
    pub fn taflove_optical(thickness: usize, dx: f64, m: f64, r_desired: f64, eta: f64) -> Self {
        let delta = thickness as f64 * dx;
        let sigma_max = -(m + 1.0) * r_desired.ln() / (2.0 * eta * delta);
        Self {
            thickness,
            m,
            r_desired,
            sigma_max,
        }
    }

    /// Distance `depth_from_interface` ∈ [0, thickness]; 0 at interior interface, thickness at outer wall.
    pub fn sigma_at_depth(&self, depth_from_interface: f64) -> f64 {
        if self.thickness == 0 {
            return 0.0;
        }
        let rho = depth_from_interface.clamp(0.0, self.thickness as f64);
        self.sigma_max * (rho / self.thickness as f64).powf(self.m)
    }

    /// Grade into left/right ends of a 1D grid of length `n`.
    pub fn grade_1d_ends(&self, n: usize) -> Vec<f64> {
        let mut sigma = vec![0.0; n];
        let t = self.thickness;
        for i in 0..t.min(n) {
            let depth = (t - i) as f64;
            let s = self.sigma_at_depth(depth);
            sigma[i] = s;
            if n > t {
                sigma[n - 1 - i] = s;
            }
        }
        sigma
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sigma_max_matches_taflove_761() {
        let p = PmlProfile::taflove(10, 1e-6, 3.0, 1e-8);
        let delta = 10.0 * 1e-6;
        let expected = -(3.0 + 1.0) * (1e-8_f64).ln() / (2.0 * ETA0 * delta);
        assert!((p.sigma_max - expected).abs() / expected < 1e-12);
    }

    #[test]
    fn grade_zero_inside() {
        let p = PmlProfile::taflove(5, 1.0, 3.0, 1e-6);
        let s = p.grade_1d_ends(20);
        assert_eq!(s[10], 0.0);
        assert!(s[0] > s[1]);
        assert!(s[19] > s[18]);
    }
}
