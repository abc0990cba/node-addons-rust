//! Cell-wise isotropic materials (+ future dispersion slots).

use crate::config::MaterialSample;
use crate::traits::MaterialModel;

/// Lookup table of media + integer index grid.
#[derive(Debug, Clone)]
pub struct MaterialGrid {
    pub nx: usize,
    pub ny: usize,
    /// Row-major material ids, length `nx * ny`.
    pub ids: Vec<u32>,
    pub catalog: Vec<MaterialSample>,
}

impl MaterialGrid {
    pub fn vacuum(nx: usize, ny: usize) -> Self {
        Self {
            nx,
            ny,
            ids: vec![0; nx * ny],
            catalog: vec![MaterialSample::VACUUM],
        }
    }

    pub fn from_matrix(
        matrix: &[Vec<u32>],
        catalog: Vec<MaterialSample>,
        target_nx: usize,
        target_ny: usize,
    ) -> Self {
        let src_ny = matrix.len().max(1);
        let src_nx = matrix.first().map(|r| r.len()).unwrap_or(1).max(1);
        let mut ids = vec![0u32; target_nx * target_ny];
        for j in 0..target_ny {
            for i in 0..target_nx {
                let si = (i * src_nx) / target_nx;
                let sj = (j * src_ny) / target_ny;
                let id = matrix
                    .get(sj)
                    .and_then(|row| row.get(si))
                    .copied()
                    .unwrap_or(0);
                ids[j * target_nx + i] = id;
            }
        }
        Self {
            nx: target_nx,
            ny: target_ny,
            ids,
            catalog: if catalog.is_empty() {
                vec![MaterialSample::VACUUM]
            } else {
                catalog
            },
        }
    }

    pub fn from_vector_1d(ids: &[u32], catalog: Vec<MaterialSample>, target_n: usize) -> Self {
        let src_n = ids.len().max(1);
        let mut out = vec![0u32; target_n];
        for i in 0..target_n {
            let si = (i * src_n) / target_n;
            out[i] = ids.get(si).copied().unwrap_or(0);
        }
        Self {
            nx: target_n,
            ny: 1,
            ids: out,
            catalog: if catalog.is_empty() {
                vec![MaterialSample::VACUUM]
            } else {
                catalog
            },
        }
    }

    #[inline]
    pub fn id_at(&self, ix: usize, iy: usize) -> u32 {
        self.ids[iy * self.nx + ix]
    }
}

impl MaterialModel for MaterialGrid {
    fn sample_at(&self, ix: usize, iy: usize, _iz: usize) -> MaterialSample {
        let id = self.id_at(ix, iy) as usize;
        self.catalog
            .get(id)
            .copied()
            .unwrap_or(MaterialSample::VACUUM)
    }
}
