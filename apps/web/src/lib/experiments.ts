import type { SimType } from '@fdtd-online/protocol'
import type { UiMaterial } from './materials'

export type ExperimentId =
  | '1d-vacuum'
  | '1d-barrier'
  | '2d-vacuum'
  | '2d-waveguide'
  | '2d-diffraction'
  | '2d-border'
  | '2d-tfsf'

export type ExperimentDef = {
  id: ExperimentId
  label: string
  blurb: string
  simType: SimType
  gridSize: number
  /** Relative source position(s); first is used for injection. */
  src: { x: number; y: number }
  omega?: number
  tau?: number
  lambda?: number
  beamsize?: number
  srcType?: number
  dataToReturn?: number
  buildMatrix: (n: number, materials: UiMaterial[]) => number[][]
}

function empty(n: number, materials: UiMaterial[]): number[][] {
  const id = materials[0]?.id ?? 0
  return Array.from({ length: n }, () => Array.from({ length: n }, () => id))
}

function empty1d(n: number, materials: UiMaterial[]): number[][] {
  const id = materials[0]?.id ?? 0
  return [Array.from({ length: n }, () => id)]
}

/** Dielectric slab in the right half of a 1×N line (legacy Barrier). */
function barrier1d(n: number, materials: UiMaterial[]): number[][] {
  const vac = materials[0]?.id ?? 0
  const diel = materials[1]?.id ?? 1
  const row = Array.from({ length: n }, (_, j) =>
    j > n * 0.5 && j < n * 0.75 ? diel : vac,
  )
  return [row]
}

function waveguide(n: number, materials: UiMaterial[]): number[][] {
  const m = empty(n, materials)
  const metal = materials[2]?.id ?? 2
  const up = Math.floor(n * 0.4)
  const down = Math.floor(n * 0.6)
  for (let j = 0; j < n; j++) {
    m[up][j] = metal
    m[down][j] = metal
  }
  return m
}

function diffraction(n: number, materials: UiMaterial[]): number[][] {
  const m = empty(n, materials)
  const diel = materials[1]?.id ?? 1
  const vac = materials[0]?.id ?? 0
  const col = Math.floor(n / 8)
  for (let i = 0; i < n; i++) m[i][col] = diel
  for (let i = 0; i < n; i += 3) m[i][col] = vac
  return m
}

function border(n: number, materials: UiMaterial[]): number[][] {
  const vac = materials[0]?.id ?? 0
  const diel = materials[1]?.id ?? 1
  return Array.from({ length: n }, (_, i) =>
    Array.from({ length: n }, (_, j) => (i > j ? vac : diel)),
  )
}

export const EXPERIMENTS: ExperimentDef[] = [
  {
    id: '1d-vacuum',
    label: '1D · free space',
    blurb: 'Gaussian×cosine pulse in vacuum with PML ends.',
    simType: '1D',
    gridSize: 64,
    src: { x: 0.2, y: 0 },
    omega: 1.0,
    tau: 8,
    buildMatrix: empty1d,
  },
  {
    id: '1d-barrier',
    label: '1D · dielectric barrier',
    blurb: 'Pulse hits a dielectric slab — reflection / transmission.',
    simType: '1D',
    gridSize: 64,
    src: { x: 0.15, y: 0 },
    omega: 0.8,
    tau: 6,
    buildMatrix: barrier1d,
  },
  {
    id: '2d-vacuum',
    label: '2D · point source',
    blurb: 'TE_z soft source in vacuum with perimeter PML.',
    simType: '2D',
    gridSize: 24,
    src: { x: 0.5, y: 0.5 },
    lambda: 50,
    beamsize: 20,
    srcType: 1,
    dataToReturn: 0,
    buildMatrix: empty,
  },
  {
    id: '2d-waveguide',
    label: '2D · waveguide',
    blurb: 'Metal-like walls guiding a wave along x.',
    simType: '2D',
    gridSize: 24,
    src: { x: 0.2, y: 0.5 },
    lambda: 40,
    beamsize: 25,
    srcType: 1,
    dataToReturn: 0,
    buildMatrix: waveguide,
  },
  {
    id: '2d-diffraction',
    label: '2D · diffraction grating',
    blurb: 'Slotted dielectric screen — diffraction lobes.',
    simType: '2D',
    gridSize: 24,
    src: { x: 0.15, y: 0.5 },
    lambda: 35,
    beamsize: 20,
    srcType: 2,
    dataToReturn: 0,
    buildMatrix: diffraction,
  },
  {
    id: '2d-border',
    label: '2D · material interface',
    blurb: 'Diagonal dielectric half-space interface.',
    simType: '2D',
    gridSize: 24,
    src: { x: 0.3, y: 0.3 },
    lambda: 45,
    beamsize: 20,
    srcType: 1,
    dataToReturn: 0,
    buildMatrix: border,
  },
  {
    id: '2d-tfsf',
    label: '2D · TF/SF plane wave',
    blurb: 'UPML + total-field / scattered-field plane-wave injection.',
    simType: '2D_TFSF',
    gridSize: 24,
    src: { x: 0.5, y: 0.5 },
    lambda: 15,
    beamsize: 10,
    dataToReturn: 0,
    buildMatrix: empty,
  },
]

export function experimentById(id: ExperimentId): ExperimentDef {
  return EXPERIMENTS.find((e) => e.id === id) ?? EXPERIMENTS[0]
}
